import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:construction_safety/utils/helpers/snackbar.dart';
import '../../../data/models/camera_model.dart';
import '../../../data/models/settings_model.dart';
import '../../../data/models/violation_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/notification_prefs.dart';
import '../../../data/services/notification_service.dart';
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
  final AuthService _auth = Get.find<AuthService>();
  late final WebSocketService _ws;

  var activeScreen = Screen.dashboard.obs;
  var violations = <ViolationModel>[].obs;
  var selectedViolation = Rxn<ViolationModel>();
  var cameras = <CameraModel>[].obs;
  var selectedCamera = Rxn<CameraModel>();
  var notificationSettings = NotificationSettings(criticalAlerts: true, mediumAlerts: true, lowAlerts: true).obs;
  var autoDetection = true.obs;

  // New-violation tracking (phone notifications ke liye)
  final Set<String> _notifiedViolationIds = {};
  bool _firstViolationsSnapshot = true;

  // Stream subscriptions
  StreamSubscription<List<ViolationModel>>? _violationsSubscription;
  StreamSubscription<List<CameraModel>>? _camerasSubscription;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

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

  Future<List<String>?> _getCameraIdsForCurrentSites() async {
    final siteIds = await _auth.getUserSiteIds();
    if (siteIds == null || siteIds.isEmpty) return null;
    final cameraIds = await _firestore.getCameraIdsBySiteIds(siteIds);
    return cameraIds.isEmpty ? null : cameraIds;
  }

  Future<List<String>?> _getCurrentSiteIds() async {
    final siteIds = await _auth.getUserSiteIds();
    return siteIds == null || siteIds.isEmpty ? null : siteIds;
  }

  Future<void> _initializeStreams() async {
    final siteIds = await _getCurrentSiteIds();
    final cameraIds = await _getCameraIdsForCurrentSites();

    // Subscribe to violations stream (real-time updates) — app start par load hota hai
    _violationsSubscription = _firestore
        .getViolationsStream(cameraIds: cameraIds, limit: 200)
        .listen(
          _onViolationsUpdate,
          onError: (e) => print('Violations stream error: $e'),
        );

    // Subscribe to cameras stream (real-time updates)
    _camerasSubscription = _firestore
        .getCamerasStream(siteIds: siteIds)
        .listen((camerasList) => cameras.assignAll(camerasList), onError: (e) => print('Cameras stream error: $e'));
  }

  void _onViolationsUpdate(List<ViolationModel> violationsList) {
    // Pehli snapshot par notify mat karo (purani violations ka spam na ho)
    if (!_firstViolationsSnapshot) {
      for (final v in violationsList) {
        if (v.status == ViolationStatus.active && !_notifiedViolationIds.contains(v.id)) {
          _notifyNewViolation(v);
        }
      }
    }
    _notifiedViolationIds.addAll(violationsList.map((v) => v.id));
    _firstViolationsSnapshot = false;
    violations.assignAll(violationsList);
  }

  /// Naye violation par settings ke hisaab se push / pop-up / sound trigger karta hai.
  void _notifyNewViolation(ViolationModel v) {
    final prefs = NotificationPrefs.to;
    final sev = v.severity.name.isEmpty
        ? ''
        : '${v.severity.name[0].toUpperCase()}${v.severity.name.substring(1)} ';
    final title = '$sev${v.type.name} Violation';
    final body = v.zone.isNotEmpty ? '${v.zone} — ${v.description}' : v.description;

    // 1) Device push notification (sound channel toggle ke hisaab se)
    if (prefs.pushNotifications) {
      NotificationService.to.showViolation(v, playSound: prefs.soundAlerts);
    }

    // 2) In-app alert pop-up (app open ho to)
    if (prefs.alertPopups) {
      SnackBarUtils.showError(body, title: title);

      // 3) Sound — agar push off hai to notification se sound nahi aaya, yahan bajao
      if (prefs.soundAlerts && !prefs.pushNotifications) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
    }
  }

  // ── Today's analytics (single source of truth — app start par stream se) ─────
  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// Aaj ki saari violations (open + resolved).
  List<ViolationModel> get todayViolations => violations.where((v) => _isToday(v.time)).toList();

  /// Aaj ki total violations.
  int get todayTotalViolations => todayViolations.length;

  /// Aaj ki open/active violations (dashboard "Open Violations").
  int get todayActiveViolations => todayViolations.where((v) => v.status == ViolationStatus.active).length;

  /// Aaj ka compliance rate (dashboard "Safety Coverage") — high-severity ratio se.
  int get todayComplianceRate {
    final today = todayViolations;
    if (today.isEmpty) return 100;
    final high = today.where((v) => v.severity == ViolationSeverity.high).length;
    return (100 - ((high / today.length) * 100).round()).clamp(0, 100).toInt();
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
    _violationsSubscription?.cancel();
    _camerasSubscription?.cancel();
    _wsSubscription?.cancel();
    super.onClose();
  }
}
