import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/models/violation_model.dart';

class DashboardController extends GetxController {
  Rx<DateTime> currentTime = DateTime.now().obs;

  RxList<CameraModel> cameras = <CameraModel>[].obs;
  RxList<ViolationModel> violations = <ViolationModel>[].obs;

  int totalWorkers = 28;

  @override
  void onInit() {
    super.onInit();

    // Sample Cameras
    cameras.assignAll([
      CameraModel(id: "CAM-01", zone: "Zone A - Entry", status: "online"),
      CameraModel(id: "CAM-02", zone: "Zone B - Storage", status: "online"),
      CameraModel(id: "CAM-03", zone: "Zone C - Scaffolding", status: "offline"),
    ]);

    // Sample Violations
    violations.assignAll([
      ViolationModel(
        type: "Helmet Missing",
        zone: "Zone A",
        description: "Worker not wearing helmet",
        time: "10:45 AM",
        status: "active",
        severity: "high",
      ),
    ]);

    // Live Clock
    ever(currentTime, (_) {});
    _startClock();
  }

  void _startClock() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      currentTime.value = DateTime.now();
      return true;
    });
  }

  List<ViolationModel> get activeViolations =>
      violations.where((v) => v.status == "active").toList();

  int get safeWorkers => totalWorkers - activeViolations.length;

  int get complianceRate =>
      ((safeWorkers / totalWorkers) * 100).round();
}
