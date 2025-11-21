import 'package:get/get.dart';
import '../../../../data/models/violation_model.dart';

class AlertsController extends GetxController {
  RxList<ViolationModel> violations = <ViolationModel>[].obs;
  Rxn<ViolationModel> selectedViolation = Rxn<ViolationModel>();

  @override
  void onInit() {
    super.onInit();

    // Temporary dummy data – later replace with API/firestore stream
    violations.assignAll([
      ViolationModel(
        id: "1",
        type: ViolationType.PPE,
        severity: ViolationSeverity.high,
        description: "No safety helmet detected",
        zone: "Zone A - Entrance",
        time: DateTime.now().subtract(Duration(minutes: 5)),
        status: ViolationStatus.active,
      ),
      ViolationModel(
        id: "2",
        type: ViolationType.Unauthorized,
        severity: ViolationSeverity.medium,
        description: "Unauthorized person entry detected",
        zone: "Zone B - Warehouse",
        time: DateTime.now().subtract(Duration(minutes: 2)),
        status: ViolationStatus.active,
      ),
    ]);
  }

  /// 🔹 Get Active Alerts
  List<ViolationModel> get activeAlerts =>
      violations.where((v) => v.status == ViolationStatus.active).toList();

  /// 🔹 Dismiss Alert
  void dismissAlert(String id) {
    violations.value = violations.map((v) {
      if (v.id == id) {
        return v.copyWith(status: ViolationStatus.dismissed);
      }
      return v;
    }).toList();
  }

  /// 🔹 Acknowledge Alert
  void acknowledgeAlert(String id) {
    violations.value = violations.map((v) {
      if (v.id == id) {
        return v.copyWith(
          status: ViolationStatus.acknowledged,
          acknowledgedBy: "Supervisor John", // Future: auto-fill from logged in user
        );
      }
      return v;
    }).toList();
  }

  /// 🔹 View Details & Navigate to next screen
  void viewDetails(ViolationModel violation) {
    selectedViolation.value = violation;
    Get.toNamed('/violationDetail', arguments: violation);
  }

  /// 🔹 Get count by severity (for dashboard & summary UI)
  int countBySeverity(ViolationSeverity s) =>
      activeAlerts.where((v) => v.severity == s).length;
}
