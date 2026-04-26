import 'dart:convert';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/safety_api_service.dart';
import '../../../../core/values/apis_url.dart';
import '../../violation_detail/bindings/violation_detail_binding.dart';
import '../../violation_detail/views/violation_detail_view.dart';

class AlertsController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;
  final AuthService _auth = Get.find<AuthService>();

  final RxList<ViolationModel> violations = <ViolationModel>[].obs;
  final Rxn<ViolationModel> selectedViolation = Rxn<ViolationModel>();
  final isLoading = false.obs;

  WebSocketChannel? _wsChannel;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchAlerts();
    _connectWebSocket();
  }

  @override
  void onClose() {
    _wsChannel?.sink.close();
    super.onClose();
  }

  // ── HTTP fetch ─────────────────────────────────────────────────────────────
  Future<void> fetchAlerts({bool unreadOnly = false}) async {
    isLoading.value = true;
    try {
      final raw = await _api.getAlerts(unreadOnly: unreadOnly);
      violations.assignAll(raw.map((e) {
        final alertMap = e as Map<String, dynamic>;
        final violationMap = alertMap['violation'] as Map<String, dynamic>? ?? alertMap;
        return ViolationModel.fromJson(violationMap);
      }).toList());
    } catch (e) {
      Get.snackbar('Alerts Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────
  Future<void> _connectWebSocket() async {
    try {
      final token = await _auth.getToken();
      if (token == null) return;
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(ApisUrl.wsAlerts(token)),
      );
      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            if (data['type'] == 'new_violation') {
              // Backend broadcasts a flat payload — remap to ViolationModel.fromJson shape
              final violationMap = <String, dynamic>{
                'id':           data['violation_id'],
                'type':         data['violation_type'],
                'severity':     data['severity'],
                'detected_at':  data['detected_at'],
                'snapshot_url': data['snapshot_url'],
                'status':       'open',
                'camera': {
                  'name': 'Camera ${data['camera_id']}',
                  'location': null,
                },
              };
              final v = ViolationModel.fromJson(violationMap);
              violations.insert(0, v);
              Get.snackbar(
                '🚨 New Violation',
                v.description,
                snackPosition: SnackPosition.TOP,
                duration: const Duration(seconds: 4),
              );
            }
          } catch (_) {}
        },
        onError: (_) => _reconnectAfterDelay(),
        onDone: () => _reconnectAfterDelay(),
      );
    } catch (_) {}
  }

  void _reconnectAfterDelay() {
    Future.delayed(const Duration(seconds: 5), () async {
      // Ensure we have a valid token (may have been refreshed by the stream poller)
      // before reconnecting the WebSocket.
      await _api.tryRefreshToken();
      _connectWebSocket();
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> markAllRead() async {
    try {
      await _api.markAllAlertsRead();
      Get.snackbar('Done', 'All alerts marked as read',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  List<ViolationModel> get activeAlerts =>
      violations.where((v) => v.status == ViolationStatus.active).toList();

  void viewDetails(ViolationModel violation) {
    selectedViolation.value = violation;
    Get.to(
      () => const ViolationDetailView(),
      arguments: violation,
      binding: ViolationDetailBinding(),
    );
  }

  int countBySeverity(ViolationSeverity s) =>
      activeAlerts.where((v) => v.severity == s).length;

  /// Local dismiss (optimistic) — view calls this
  void dismissAlert(String id) {
    final i = violations.indexWhere((v) => v.id == id);
    if (i != -1) violations[i] = violations[i].copyWith(status: ViolationStatus.dismissed);
  }

  /// Local acknowledge (optimistic) — view calls this
  void acknowledgeAlert(String id) {
    final i = violations.indexWhere((v) => v.id == id);
    if (i != -1) {
      violations[i] = violations[i].copyWith(
        status: ViolationStatus.acknowledged,
        acknowledgedBy: 'Supervisor',
      );
    }
  }
}
