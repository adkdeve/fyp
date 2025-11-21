import 'dart:async';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/models/violation_model.dart';

class DashboardController extends GetxController {
  /// Observable data
  RxList<CameraModel> cameras = <CameraModel>[].obs;
  RxList<ViolationModel> violations = <ViolationModel>[].obs;
  Rxn<CameraModel> selectedCamera = Rxn<CameraModel>();
  Rx<DateTime> currentTime = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();

    // Update live clock
    Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now();
    });

    // Sample cameras
    cameras.assignAll([
      CameraModel(id: "CAM-001", zone: "Zone A - Main Entrance", status: "online"),
      CameraModel(id: "CAM-002", zone: "Zone B - Construction Area", status: "online"),
      CameraModel(id: "CAM-003", zone: "Zone C - Storage Area", status: "offline"),
    ]);

    // Sample violations using ENUMS, NOT string literals ❌
    violations.assignAll([
      ViolationModel(
        id: "V1",
        type: ViolationType.PPE,
        severity: ViolationSeverity.high,
        description: "Worker not wearing helmet",
        zone: "Zone B - Construction Area",
        time: DateTime.now().subtract(Duration(minutes: 10)),
        status: ViolationStatus.active,
      ),
      ViolationModel(
        id: "V2",
        type: ViolationType.Unauthorized,
        severity: ViolationSeverity.medium,
        description: "Unauthorized entry detected",
        zone: "Zone C - Storage Area",
        time: DateTime.now().subtract(Duration(minutes: 5)),
        status: ViolationStatus.active,
      ),
    ]);
  }

  /// 🔹 Camera selection
  void selectCamera(CameraModel? camera) {
    selectedCamera.value = camera;
  }

  /// 🔹 Computed stats (derived data)
  int get totalWorkers => 28;

  int get activeViolationsCount =>
      violations.where((v) => v.status == ViolationStatus.active).length;

  int get safeWorkers => totalWorkers - activeViolationsCount;

  int get complianceRate =>
      ((safeWorkers / totalWorkers) * 100).round();

  ViolationModel? get mostRecentViolation {
    final active = violations
        .where((v) => v.status == ViolationStatus.active)
        .toList();
    active.sort((a, b) => b.time.compareTo(a.time));
    return active.isNotEmpty ? active.first : null;
  }

  /// 🔹 Filtering alerts by severity – useful for colored summary cards
  int countBySeverity(ViolationSeverity severity) =>
      violations.where((v) => v.severity == severity).length;
}
