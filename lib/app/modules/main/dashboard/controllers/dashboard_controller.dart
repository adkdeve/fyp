import 'dart:async';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/models/violation_model.dart';

class DashboardController extends GetxController {
  var cameras = <CameraModel>[].obs;
  var violations = <ViolationModel>[].obs;
  var selectedCamera = Rxn<CameraModel>();
  var currentTime = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();

    // Update current time every second
    Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now();
    });

    // Sample cameras
    cameras.addAll([
      CameraModel(id: "CAM-001", zone: "Zone A", status: "online"),
      CameraModel(id: "CAM-002", zone: "Zone B", status: "online"),
      CameraModel(id: "CAM-003", zone: "Zone C", status: "offline"),
    ]);

    // Sample violations
    violations.addAll([
      ViolationModel(
        type: "PPE Missing",
        zone: "Zone B",
        description: "Worker missing helmet",
        severity: "high",
        status: "active",
        time: "10:30 AM",
      ),
    ]);
  }


  void selectCamera(CameraModel? camera) {
    selectedCamera.value = camera;
  }

  int get totalWorkers => 28;

  int get activeViolationsCount =>
      violations.where((v) => v.status == 'active').length;

  int get safeWorkers => totalWorkers - activeViolationsCount;

  int get complianceRate =>
      ((safeWorkers / totalWorkers) * 100).round();

  ViolationModel? get mostRecentViolation =>
      violations.firstWhereOrNull((v) => v.status == 'active');
}
