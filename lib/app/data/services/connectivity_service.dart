import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

import '../../../utils/dialogs/internet_connectivity_dialog.dart';

/// App-wide internet connectivity watcher.
///
/// App start par registered hoti hai (AppBinding). Jab net chala jaye to
/// `internetConnectivityAlterDialog()` dikhati hai, aur wapas aane par usay
/// khud band kar deti hai. Per-request check ki zaroorat nahi rehti.
class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Reactive online/offline state — UI isko bind kar sakti hai (e.g. banner).
  final RxBool isOnline = true.obs;

  /// Synchronous current state — network calls se pehle guard ke liye.
  bool get online => isOnline.value;

  bool _dialogShown = false;

  /// GetX singleton accessor
  static ConnectivityService get to => Get.find<ConnectivityService>();

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    // Initial state
    final initial = await _connectivity.checkConnectivity();
    _updateStatus(initial);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // v6: list aata hai — agar har result `none` hai to offline.
    final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    isOnline.value = !offline;

    if (offline) {
      _showOfflineDialog();
    } else {
      _dismissOfflineDialog();
    }
  }

  void _showOfflineDialog() {
    if (_dialogShown) return;
    _dialogShown = true;
    internetConnectivityAlterDialog().then((_) => _dialogShown = false);
  }

  void _dismissOfflineDialog() {
    if (_dialogShown && (Get.isDialogOpen ?? false)) {
      Get.back();
    }
    _dialogShown = false;
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
