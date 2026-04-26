import 'dart:async';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/safety_api_service.dart';

class DashboardController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;

  // ── Observables ────────────────────────────────────────────────────────────
  final cameras = <CameraModel>[].obs;
  final violations = <ViolationModel>[].obs;
  final Rxn<CameraModel> selectedCamera = Rxn<CameraModel>();
  final Rx<DateTime> currentTime = DateTime.now().obs;

  // Summary stats from backend
  final totalViolationsToday = 0.obs;
  final resolvedToday = 0.obs;
  final isLoading = false.obs;

  Timer? _clockTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now();
    });
    fetchAll();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    super.onClose();
  }

  // ── Data fetching ──────────────────────────────────────────────────────────
  Future<void> fetchAll() async {
    isLoading.value = true;
    try {
      await Future.wait([fetchCameras(), fetchRecentViolations(), fetchSummary()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCameras() async {
    try {
      final raw = await _api.getCameras(enabledOnly: true);
      cameras.assignAll(raw.map((e) => CameraModel.fromJson(e)).toList());
      if (cameras.isNotEmpty) selectedCamera.value = cameras.first;
    } catch (e) {
      Get.snackbar('Camera Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> fetchRecentViolations() async {
    try {
      final raw = await _api.getViolations(status: 'open', limit: 20);
      violations.assignAll(raw.map((e) => ViolationModel.fromJson(e)).toList());
    } catch (e) {
      // Non-fatal — dashboard still shows cameras
    }
  }

  Future<void> fetchSummary() async {
    try {
      final s = await _api.getSummary(days: 1);
      totalViolationsToday.value = (s['total_violations'] as int?) ?? 0;
      resolvedToday.value = (s['resolved'] as int?) ?? 0;
    } catch (_) {}
  }

  // ── Camera selection ───────────────────────────────────────────────────────
  void selectCamera(CameraModel? camera) {
    selectedCamera.value = camera;
  }

  // ── Computed stats ─────────────────────────────────────────────────────────
  int get totalWorkers => 28; // TODO: pull from /api/v1/workers when endpoint added

  int get activeViolationsCount => violations.length;

  int get safeWorkers =>
      (totalWorkers - activeViolationsCount).clamp(0, totalWorkers);

  int get complianceRate =>
      totalWorkers == 0 ? 100 : ((safeWorkers / totalWorkers) * 100).round();

  ViolationModel? get mostRecentViolation {
    if (violations.isEmpty) return null;
    final sorted = [...violations]..sort((a, b) => b.time.compareTo(a.time));
    return sorted.first;
  }

  int countBySeverity(ViolationSeverity severity) =>
      violations.where((v) => v.severity == severity).length;

  int get onlineCameraCount =>
      cameras.where((c) => c.status.toLowerCase() == 'online').length;
}
