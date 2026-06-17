import 'dart:async';
import 'package:get/get.dart';
import 'package:construction_safety/utils/helpers/snackbar.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../controllers/main_controller.dart';

class DashboardController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final AuthService _auth = Get.find<AuthService>();
  final MainController _main = Get.find<MainController>();

  // ── Observables ────────────────────────────────────────────────────────────
  final cameras = <CameraModel>[].obs;
  final violations = <ViolationModel>[].obs;
  final Rxn<CameraModel> selectedCamera = Rxn<CameraModel>();
  final Rx<DateTime> currentTime = DateTime.now().obs;

  // Summary stats from backend
  final totalViolationsToday = 0.obs;
  final resolvedToday = 0.obs;
  final activeZonesValue = 0.obs;
  final compliantCamerasValue = 0.obs;
  final complianceRateValue = 100.obs;
  final isLoading = false.obs;

  Timer? _clockTimer;
  Worker? _violationsWorker;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    violations.assignAll(_main.violations);
    selectedCamera.value = _main.selectedCamera.value;
    _violationsWorker = ever<List<ViolationModel>>(_main.violations, (items) {
      violations.assignAll(items);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now();
    });
    fetchAll();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    _violationsWorker?.dispose();
    super.onClose();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────
  Future<void> fetchAll() async {
    isLoading.value = true;
    try {
      // Violations MainController ke stream se aati hain (app start par, all statuses) —
      // yahan dobara fetch nahi karte taake _main.violations open-only se overwrite na ho.
      await Future.wait([fetchCameras(), fetchSummary()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<String>?> _getSiteIds() async {
    final siteIds = await _auth.getUserSiteIds();
    return siteIds == null || siteIds.isEmpty ? null : siteIds;
  }

  Future<void> fetchCameras() async {
    try {
      final siteIds = await _getSiteIds();
      final raw = await _firestore.getCameras(siteIds: siteIds);
      cameras.assignAll(raw);
      if (cameras.isNotEmpty) selectedCamera.value = cameras.first;
      if (Get.isRegistered<MainController>()) {
        Get.find<MainController>().setCameras(cameras);
      }
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Camera Error');
    }
  }

  Future<void> fetchSummary() async {
    try {
      final s = await _firestore.getSummary(1);
      totalViolationsToday.value = (s['total_violations'] as int?) ?? 0;
      resolvedToday.value = (s['resolved'] as int?) ?? 0;
      activeZonesValue.value = (s['active_zones'] as int?) ?? 0;
      compliantCamerasValue.value = (s['compliant_cameras'] as int?) ?? 0;
      complianceRateValue.value = (s['compliance_rate'] as int?) ?? 100;
    } catch (_) {}
  }

  // ── Camera selection ───────────────────────────────────────────────────────
  void selectCamera(CameraModel? camera) {
    selectedCamera.value = camera;
  }

  // ── Computed stats — MainController (single source, app start par load) se ───
  /// Aaj ke open/active violations (dashboard "Open Violations" card).
  int get activeViolationsCount => _main.todayActiveViolations;

  int get activeZones => activeZonesValue.value;

  int get compliantCameras => compliantCamerasValue.value.clamp(0, activeZones).toInt();

  /// Aaj ka compliance (dashboard "Safety Coverage" card).
  int get complianceRate => _main.todayComplianceRate;

  ViolationModel? get mostRecentViolation {
    if (violations.isEmpty) return null;
    final sorted = [...violations]..sort((a, b) => b.time.compareTo(a.time));
    return sorted.first;
  }

  int countBySeverity(ViolationSeverity severity) => violations.where((v) => v.severity == severity).length;

  int get onlineCameraCount => cameras.where((c) => c.status.toLowerCase() == 'online').length;

  int get enabledCameraCount => cameras.where((c) => c.enabled).length;
}
