import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../../core/values/apis_url.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/services/auth_service.dart';

class CameraFeedController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();

  final zoom = 1.0.obs;
  final selectedCamera = Rxn<CameraModel>();
  final currentTime = ''.obs;
  final frameBytes = Rx<Uint8List?>(null);
  final isStreamLoading = true.obs;
  final streamError = false.obs;

  Timer? _clockTimer;
  Timer? _frameTimer;
  String? _token;
  final _client = http.Client();
  bool _fetching = false;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is CameraModel) {
      selectedCamera.value = Get.arguments as CameraModel;
      print(
        '🎥 CameraFeedController: Got camera from arguments: ${selectedCamera.value?.name} (ID: ${selectedCamera.value?.id})',
      );
    } else {
      print('⚠️ CameraFeedController: No camera arguments passed');
      selectedCamera.value = CameraModel(
        id: 'nn212mrc7aJSTagXDzdL', // Use actual Firebase camera ID
        name: 'Camera 1',
        rtspUrl: '',
        status: 'online',
        enabled: true,
        fpsTarget: 5,
      );
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
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

  Future<void> _initStream() async {
    _token = await _auth.getToken();
    _startFramePolling();
  }

  void _startFramePolling() {
    final camera = selectedCamera.value;
    final camId = camera?.id;
    if (camId == null) return;

    final configuredFps = camera?.fpsTarget ?? 5;
    final fps = configuredFps < 1
        ? 1
        : configuredFps > 5
        ? 5
        : configuredFps;
    final intervalMs = (1000 / fps).round();

    _frameTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _fetchFrame(camId);
    });
    _fetchFrame(camId);
  }

  Future<void> _fetchFrame(dynamic cameraId) async {
    if (_fetching) return;
    _fetching = true;
    try {
      final url = Uri.parse(ApisUrl.streamFrame(cameraId));

      Future<http.StreamedResponse> doRequest() {
        final req = http.Request('GET', url);
        if (_token != null) req.headers['Authorization'] = 'Bearer $_token';

        // 🌟 CRUCIAL: Add this header to skip localtunnel's landing screen
        req.headers['bypass-tunnel-reminder'] = 'true';

        return _client.send(req).timeout(const Duration(seconds: 8));
      }

      var res = await doRequest();

      if (res.statusCode == 401) {
        await res.stream.drain<void>();
        _token = await _auth.getToken();
        res = await doRequest();
      }

      if (res.statusCode == 200) {
        final bytes = await res.stream.toBytes();
        if (bytes.isNotEmpty) {
          frameBytes.value = bytes;
          isStreamLoading.value = false;
          streamError.value = false;
        }
      } else {
        print('❌ Frame request failed: ${res.statusCode}');
        streamError.value = true;
        await res.stream.drain<void>(); // Cleanup to prevent memory leaks
      }
    } catch (e) {
      print('❌ Frame fetch error: $e');
      streamError.value = true;
    } finally {
      _fetching = false;
    }
  }

  void zoomIn() {
    if (zoom.value < 3.0) zoom.value += 0.5;
  }

  void zoomOut() {
    if (zoom.value > 1.0) zoom.value -= 0.5;
  }

  void resetZoom() => zoom.value = 1.0;

  Future<void> takeSnapshot() async {
    final camId = selectedCamera.value?.id;
    if (camId == null) return;
    Get.snackbar('Snapshot', 'Snapshot functionality pending implementation', snackPosition: SnackPosition.BOTTOM);
  }

  void enterFullscreen() {
    final bytes = frameBytes.value;
    if (bytes == null) return;
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(child: RotatedBox(quarterTurns: 0, child: Image.memory(bytes))),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get hasDetection => false;

  @override
  void onClose() {
    _clockTimer?.cancel();
    _frameTimer?.cancel();
    _client.close();
    super.onClose();
  }
}
