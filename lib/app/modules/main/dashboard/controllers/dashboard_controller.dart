import 'dart:async';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/firestore_service.dart';
import '../../controllers/main_controller.dart';

class DashboardController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
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
      await Future.wait([fetchCameras(), fetchRecentViolations(), fetchSummary()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCameras() async {
    try {
      final raw = await _firestore.getCameras();
      cameras.assignAll(raw);
      if (cameras.isNotEmpty) selectedCamera.value = cameras.first;
      if (Get.isRegistered<MainController>()) {
        Get.find<MainController>().setCameras(cameras);
      }
    } catch (e) {
      Get.snackbar('Camera Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> fetchRecentViolations() async {
    try {
      final raw = await _firestore.getViolations(status: 'open', limit: 200);
      violations.assignAll(raw);
      if (Get.isRegistered<MainController>()) {
        Get.find<MainController>().setViolations(violations);
      }
    } catch (e) {
      // Non-fatal — dashboard still shows cameras
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

  // ── Computed stats ─────────────────────────────────────────────────────────
  int get activeViolationsCount => violations.where((v) => v.status == ViolationStatus.active).length;

  int get activeZones => activeZonesValue.value;

  int get compliantCameras => compliantCamerasValue.value.clamp(0, activeZones).toInt();

  int get complianceRate => complianceRateValue.value.clamp(0, 100).toInt();

  ViolationModel? get mostRecentViolation {
    if (violations.isEmpty) return null;
    final sorted = [...violations]..sort((a, b) => b.time.compareTo(a.time));
    return sorted.first;
  }

  int countBySeverity(ViolationSeverity severity) => violations.where((v) => v.severity == severity).length;

  int get onlineCameraCount => cameras.where((c) => c.status.toLowerCase() == 'online').length;

  int get enabledCameraCount => cameras.where((c) => c.enabled).length;
}
