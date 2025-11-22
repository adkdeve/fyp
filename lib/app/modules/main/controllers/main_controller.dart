// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../../../../utils/helpers/tab_fetch_manager.dart';
//
// class MainController extends GetxController {
//   final index = 0.obs;
//
//   // Tab fetch manager
//   late final TabFetchManager _tabFetchManager;
//
//   List<Widget> get currentView => const [];
//
//   @override
//   void onInit() {
//     super.onInit();
//
//     // Initialize tab fetch manager and register controller fetchers.
//     _tabFetchManager = TabFetchManager(defaultTTL: const Duration(minutes: 5));
//
//     // Register fetchers. Controllers can be registered lazily; check Get.isRegistered
//     _tabFetchManager.registerFetcher(AppTab.home, ({bool force = false}) async {
//       // if (Get.isRegistered<HomeController>()) {
//       //   await Get.find<HomeController>().fetchIfNeeded(force: force);
//       // }
//     });
//
//     // Listen to index changes and ask manager to maybeFetch
//     ever(index, (i) async {
//       final tab = AppTab.values[i];
//       await _tabFetchManager.maybeFetch(tab);
//     });
//   }
//
//   /// Expose method for manual refresh (e.g. pull-to-refresh in UI)
//   Future<void> refreshTab(AppTab tab) async {
//     await _tabFetchManager.forceFetch(tab);
//   }
//
//   /// Helper to clear caches on logout or major state changes
//   void resetCaches() {
//     _tabFetchManager.resetAll();
//   }
//
// }

import 'package:get/get.dart';

// Import your existing models
import '../../../data/models/camera_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/violation_model.dart';

// Enums (keeping only what's not in your models)
enum Screen {
  dashboard,
  alerts,
  history,
  analytics,
  settings,
  violationDetail,
  cameraManagement,
  cameraFeed,
  profile,
  help,
  terms,
}

class MainController extends GetxController {
  // Reactive state using your existing models
  var activeScreen = Screen.dashboard.obs;
  var violations = <ViolationModel>[].obs;
  var selectedViolation = Rxn<ViolationModel>();
  var cameras = <CameraModel>[].obs;
  var selectedCamera = Rxn<CameraModel>();
  var notificationSettings = NotificationSettings(
    criticalAlerts: true,
    mediumAlerts: true,
    dailySummary: false,
  ).obs;
  var autoDetection = true.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeData();
  }

  void _initializeData() {
    // Initialize violations using your ViolationModel
    violations.assignAll([
      ViolationModel(
        id: "V001",
        type: ViolationType.PPE,
        severity: ViolationSeverity.high,
        zone: "Zone B - Construction Area",
        description: "Worker missing hard hat",
        time: DateTime.now().subtract(const Duration(minutes: 2)),
        status: ViolationStatus.active,
      ),
      ViolationModel(
        id: "V002",
        type: ViolationType.Unauthorized,
        severity: ViolationSeverity.high,
        zone: "Zone D - Scaffolding",
        description: "Unauthorized personnel in restricted area",
        time: DateTime.now().subtract(const Duration(minutes: 5)),
        status: ViolationStatus.active,
      ),
      ViolationModel(
        id: "V003",
        type: ViolationType.PPE,
        severity: ViolationSeverity.medium,
        zone: "Zone A - Main Entrance",
        description: "Worker missing safety vest",
        time: DateTime.now().subtract(const Duration(minutes: 12)),
        status: ViolationStatus.active,
      ),
    ]);

    // Initialize cameras using your CameraModel
    cameras.assignAll([
      CameraModel(
        id: "CAM-001",
        zone: "Zone A - Main Entrance",
        status: "online",
      ),
      CameraModel(
        id: "CAM-002",
        zone: "Zone B - Construction Area",
        status: "online",
      ),
      CameraModel(
        id: "CAM-003",
        zone: "Zone C - Storage Area",
        status: "online",
      ),
      CameraModel(
        id: "CAM-004",
        zone: "Zone D - Scaffolding",
        status: "online",
      ),
    ]);
  }

  // Screen navigation methods
  void setActiveScreen(Screen screen) {
    activeScreen.value = screen;
  }

  void setSelectedViolation(ViolationModel? violation) {
    selectedViolation.value = violation;
  }

  void setSelectedCamera(CameraModel? camera) {
    selectedCamera.value = camera;
  }

  void setViolations(List<ViolationModel> newViolations) {
    violations.assignAll(newViolations);
  }

  void setCameras(List<CameraModel> newCameras) {
    cameras.assignAll(newCameras);
  }

  void setNotificationSettings(NotificationSettings settings) {
    notificationSettings.value = settings;
  }

  void setAutoDetection(bool enabled) {
    autoDetection.value = enabled;
  }

  // Helper methods
  int get activeViolationsCount {
    return violations.where((v) => v.status == ViolationStatus.active).length;
  }

  bool get showBottomNav {
    return ![
      Screen.violationDetail,
      Screen.cameraManagement,
      Screen.cameraFeed,
      Screen.profile,
      Screen.help,
      Screen.terms,
    ].contains(activeScreen.value);
  }

  // Violation management methods
  void acknowledgeViolation(String violationId, String acknowledgedBy) {
    final index = violations.indexWhere((v) => v.id == violationId);
    if (index != -1) {
      final violation = violations[index];
      violations[index] = violation.copyWith(
        status: ViolationStatus.acknowledged,
        acknowledgedBy: acknowledgedBy,
      );
      violations.refresh();
    }
  }

  void resolveViolation(String violationId) {
    final index = violations.indexWhere((v) => v.id == violationId);
    if (index != -1) {
      final violation = violations[index];
      violations[index] = violation.copyWith(
        status: ViolationStatus.resolved,
      );
      violations.refresh();
    }
  }

  void dismissViolation(String violationId) {
    final index = violations.indexWhere((v) => v.id == violationId);
    if (index != -1) {
      final violation = violations[index];
      violations[index] = violation.copyWith(
        status: ViolationStatus.dismissed,
      );
      violations.refresh();
    }
  }

  // Camera management methods
  void updateCameraStatus(String cameraId, String status) {
    final index = cameras.indexWhere((c) => c.id == cameraId);
    if (index != -1) {
      final camera = cameras[index];
      cameras[index] = camera.copyWith(status: status);
      cameras.refresh();
    }
  }

  // Filter methods
  List<ViolationModel> getViolationsByStatus(ViolationStatus status) {
    return violations.where((v) => v.status == status).toList();
  }

  List<ViolationModel> getViolationsByType(ViolationType type) {
    return violations.where((v) => v.type == type).toList();
  }

  List<ViolationModel> getViolationsBySeverity(ViolationSeverity severity) {
    return violations.where((v) => v.severity == severity).toList();
  }

  List<CameraModel> getOnlineCameras() {
    return cameras.where((c) => c.cameraStatus == CameraStatus.online).toList();
  }

  List<CameraModel> getOfflineCameras() {
    return cameras.where((c) => c.cameraStatus == CameraStatus.offline).toList();
  }

  // Statistics methods
  Map<ViolationType, int> getViolationTypeCounts() {
    final counts = <ViolationType, int>{};
    for (final violation in violations) {
      counts[violation.type] = (counts[violation.type] ?? 0) + 1;
    }
    return counts;
  }

  Map<ViolationSeverity, int> getViolationSeverityCounts() {
    final counts = <ViolationSeverity, int>{};
    for (final violation in violations) {
      counts[violation.severity] = (counts[violation.severity] ?? 0) + 1;
    }
    return counts;
  }

  int getTotalResolvedViolations() {
    return violations.where((v) => v.status == ViolationStatus.resolved).length;
  }

  double getResolutionRate() {
    if (violations.isEmpty) return 0.0;
    final resolvedCount = getTotalResolvedViolations();
    return (resolvedCount / violations.length) * 100;
  }
}