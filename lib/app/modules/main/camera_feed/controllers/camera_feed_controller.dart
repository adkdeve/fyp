import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/safety_api_service.dart';

class CameraFeedController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();

  var zoom = 1.0.obs;
  var isRecording = false.obs;
  var selectedCamera = Rxn<CameraModel>();
  var currentTime = ''.obs;

  // Live frame
  final Rx<Uint8List?> frameBytes = Rx<Uint8List?>(null);
  final isStreamLoading = true.obs;
  final streamError = false.obs;

  Timer? _clockTimer;
  Timer? _frameTimer;
  String? _token;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is CameraModel) {
      selectedCamera.value = Get.arguments as CameraModel;
    } else {
      selectedCamera.value = CameraModel(
        id: 1, name: 'Camera 1', rtspUrl: '', status: 'online', enabled: true);
    }
    _clockTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _updateTime());
    _updateTime();
    _initStream();
  }

  void _updateTime() {
    final now = DateTime.now();
    currentTime.value =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  // Persistent client — one connection reused for all frame fetches
  final _client = http.Client();
  bool _fetching = false;

  Future<void> _initStream() async {
    _token = await _auth.getToken();
    _startFramePolling();
  }

  void _startFramePolling() {
    final camId = selectedCamera.value?.id;
    if (camId == null) return;

    // 1 fps matches backend YOLO processing rate — no point going faster
    _frameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchFrame(camId);
    });
    // Fetch first frame immediately
    _fetchFrame(camId);
  }

  Future<void> _fetchFrame(int cameraId) async {
    if (_fetching) return;          // skip if previous request still in flight
    _fetching = true;
    try {
      final url = Uri.parse('${AppConfig.baseUrl}stream/$cameraId/frame');

      Future<http.StreamedResponse> Function() doRequest = () {
        final req = http.Request('GET', url);
        if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
        return _client.send(req).timeout(const Duration(seconds: 4));
      };

      var res = await doRequest();

      // ── 401 → refresh token, then retry once ──────────────────────────────
      if (res.statusCode == 401) {
        await res.stream.drain<void>();           // consume body before retry
        final refreshed = await SafetyApiService.to.tryRefreshToken();
        if (refreshed) {
          _token = await _auth.getToken();         // pick up the new token
          res   = await doRequest();               // one retry
        } else {
          // Refresh token also expired — force re-login
          await _auth.logout();
          Get.offAllNamed('/login');
          return;
        }
      }

      if (res.statusCode == 200) {
        final bytes = await res.stream.toBytes();
        if (bytes.isNotEmpty) {
          frameBytes.value = bytes;
          isStreamLoading.value = false;
          streamError.value = false;
        }
      }
    } catch (_) {
      streamError.value = true;
    } finally {
      _fetching = false;
    }
  }

  void zoomIn()    { if (zoom.value < 3.0) zoom.value += 0.5; }
  void zoomOut()   { if (zoom.value > 1.0) zoom.value -= 0.5; }
  void resetZoom() => zoom.value = 1.0;

  void toggleRecording() => isRecording.value = !isRecording.value;

  void takeSnapshot() {
    Get.dialog(AlertDialog(
      title: const Text('Snapshot Captured'),
      content: const Text('Current frame saved.'),
      actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
    ));
  }

  void enterFullscreen() {}
  void downloadRecording() {}

  bool get hasDetection => false;

  @override
  void onClose() {
    _clockTimer?.cancel();
    _frameTimer?.cancel();
    _client.close();
    super.onClose();
  }
}
