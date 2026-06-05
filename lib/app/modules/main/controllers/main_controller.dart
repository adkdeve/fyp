import 'dart:async';
import 'package:get/get.dart';
import '../../../data/models/camera_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/violation_model.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/websocket_service.dart';

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
  final FirestoreService _firestore = FirestoreService.to;
  late final WebSocketService _ws;

  var activeScreen = Screen.dashboard.obs;
  var violations = <ViolationModel>[].obs;
  var selectedViolation = Rxn<ViolationModel>();
  var cameras = <CameraModel>[].obs;
  var selectedCamera = Rxn<CameraModel>();
  var notificationSettings = NotificationSettings(criticalAlerts: true, mediumAlerts: true, lowAlerts: true).obs;
  var autoDetection = true.obs;

  // Stream subscriptions
  late StreamSubscription<List<ViolationModel>> _violationsSubscription;
  late StreamSubscription<List<CameraModel>> _camerasSubscription;
  late StreamSubscription<Map<String, dynamic>> _wsSubscription;

  @override
  void onInit() {
    super.onInit();
    _initializeWebSocket();
    _initializeStreams();
  }

  void _initializeWebSocket() {
    try {
      _ws = WebSocketService.to;
      // Connect to WebSocket if not already connected
      if (!_ws.isConnected) {
        _ws.connect();
      }

      // Listen to WebSocket violations stream
      _wsSubscription = _ws.violationStream.listen(
        (message) => _handleWebSocketMessage(message),
        onError: (e) => print('WebSocket error: $e'),
      );
    } catch (e) {
      print('WebSocket initialization error: $e');
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    if (type == 'new_violation') {
      print('New violation received via WebSocket');

      // Create violation model from WebSocket payload
      final violation = ViolationModel.fromJson({
        'id': message['violation_id'],
        'camera_id': message['camera_id'],
        'camera': {'id': message['camera_id'], 'name': message['camera_name']},
        'type': message['violation_type'],
        'severity': message['severity'],
        'confidence': message['confidence'],
        'snapshot_url': message['snapshot_url'],
        'detected_at': message['detected_at'],
        'status': 'open',
      });

      // Update violations list with new violation
      upsertViolation(violation);
    }
  }

  void _initializeStreams() {
    // Subscribe to violations stream (real-time updates)
    _violationsSubscription = _firestore
        .getViolationsStream(limit: 100)
        .listen(
          (violationsList) => violations.assignAll(violationsList),
          onError: (e) => print('Violations stream error: $e'),
        );

    // Subscribe to cameras stream (real-time updates)
    _camerasSubscription = _firestore.getCamerasStream().listen(
      (camerasList) => cameras.assignAll(camerasList),
      onError: (e) => print('Cameras stream error: $e'),
    );
  }

  // Screen navigation
  void setActiveScreen(Screen screen) => activeScreen.value = screen;
  void setSelectedViolation(ViolationModel? v) => selectedViolation.value = v;
  void setSelectedCamera(CameraModel? c) => selectedCamera.value = c;
  void setViolations(List<ViolationModel> list) => violations.assignAll(list);
  void setCameras(List<CameraModel> list) => cameras.assignAll(list);
  void setNotificationSettings(NotificationSettings s) => notificationSettings.value = s;
  void setAutoDetection(bool enabled) => autoDetection.value = enabled;

  bool get showBottomNav => ![
    Screen.violationDetail,
    Screen.cameraManagement,
    Screen.cameraFeed,
    Screen.profile,
    Screen.help,
    Screen.terms,
  ].contains(activeScreen.value);

  int get activeViolationsCount => violations.where((v) => v.status == ViolationStatus.active).length;

  void upsertViolation(ViolationModel violation) {
    final index = violations.indexWhere((v) => v.id == violation.id);
    if (index == -1) {
      violations.insert(0, violation);
    } else {
      violations[index] = violation;
      violations.refresh();
    }
    if (selectedViolation.value?.id == violation.id) {
      selectedViolation.value = violation;
    }
  }

  void upsertCamera(CameraModel camera) {
    final index = cameras.indexWhere((c) => c.id == camera.id);
    if (index == -1) {
      cameras.insert(0, camera);
    } else {
      cameras[index] = camera;
      cameras.refresh();
    }
    if (selectedCamera.value?.id == camera.id) {
      selectedCamera.value = camera;
    }
  }

  // Violation helpers
  void acknowledgeViolation(String id, String by) {
    final i = violations.indexWhere((v) => v.id == id);
    if (i != -1) {
      violations[i] = violations[i].copyWith(status: ViolationStatus.acknowledged, acknowledgedBy: by);
      violations.refresh();
    }
  }

  Future<void> resolveViolation(String id, String notes) async {
    await _firestore.resolveViolation(id, status: 'resolved', notes: notes);
    final i = violations.indexWhere((v) => v.id == id);
    if (i != -1) {
      violations[i] = violations[i].copyWith(status: ViolationStatus.resolved);
      violations.refresh();
    }
  }

  void dismissViolation(String id) {
    final i = violations.indexWhere((v) => v.id == id);
    if (i != -1) {
      violations[i] = violations[i].copyWith(status: ViolationStatus.dismissed);
      violations.refresh();
    }
  }

  // Camera helpers
  void updateCameraStatus(int cameraId, String status) {
    final i = cameras.indexWhere((c) => c.id == cameraId);
    if (i != -1) {
      cameras[i] = cameras[i].copyWith(status: status);
      cameras.refresh();
    }
  }

  // Filters
  List<ViolationModel> getViolationsByStatus(ViolationStatus s) => violations.where((v) => v.status == s).toList();
  List<ViolationModel> getViolationsByType(ViolationType t) => violations.where((v) => v.type == t).toList();
  List<ViolationModel> getViolationsBySeverity(ViolationSeverity s) =>
      violations.where((v) => v.severity == s).toList();
  List<CameraModel> getOnlineCameras() => cameras.where((c) => c.cameraStatus == CameraStatus.online).toList();
  List<CameraModel> getOfflineCameras() => cameras.where((c) => c.cameraStatus == CameraStatus.offline).toList();

  // Stats
  Map<ViolationType, int> getViolationTypeCounts() {
    final counts = <ViolationType, int>{};
    for (final v in violations) {
      counts[v.type] = (counts[v.type] ?? 0) + 1;
    }
    return counts;
  }

  int getTotalResolvedViolations() => violations.where((v) => v.status == ViolationStatus.resolved).length;

  double getResolutionRate() {
    if (violations.isEmpty) return 0.0;
    return (getTotalResolvedViolations() / violations.length) * 100;
  }

  @override
  void onClose() {
    _violationsSubscription.cancel();
    _camerasSubscription.cancel();
    _wsSubscription.cancel();
    super.onClose();
  }
}
