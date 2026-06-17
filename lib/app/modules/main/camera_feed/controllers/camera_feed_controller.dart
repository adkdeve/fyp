import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:construction_safety/utils/helpers/snackbar.dart';

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

  // ── Safe Zone (restricted zone polygon) ────────────────────────────────────
  final isDrawingZone = false.obs;
  final isZoneSaving = false.obs;
  // Points NORMALIZED 0..1 (frame width/height ke fraction) — resolution independent.
  final zonePoints = <Offset>[].obs;

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
    _loadZone();
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

  /// Current live frame ko JPEG file ke tor par save karta hai.
  Future<void> takeSnapshot() async {
    final bytes = frameBytes.value;
    if (bytes == null || bytes.isEmpty) {
      SnackBarUtils.showError('No live frame available to capture yet.', title: 'Snapshot');
      return;
    }
    try {
      final camId = selectedCamera.value?.id ?? 'camera';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}snapshot_${camId}_$ts.jpg');
      await file.writeAsBytes(bytes);
      SnackBarUtils.showSnackBar(file.path, title: 'Snapshot Saved');
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Snapshot Failed');
    }
  }

  /// Fullscreen landscape live view — frame poora fit hota hai (cut nahi), zoom apply hota hai.
  void enterFullscreen() {
    if (frameBytes.value == null) return;

    // Landscape mein switch karo + immersive (status/nav bar hide)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Obx(() {
              final b = frameBytes.value;
              if (b == null) return const SizedBox.shrink();
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Transform.scale(
                    scale: zoom.value,
                    child: Image.memory(b, gaplessPlayback: true, fit: BoxFit.contain),
                  ),
                ),
              );
            }),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
      barrierColor: Colors.black,
    ).then((_) => _exitFullscreen());
  }

  void _exitFullscreen() {
    // Portrait par wapas
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── Safe Zone ───────────────────────────────────────────────────────────────
  /// Backend se mojooda zone polygon load karo (normalized points).
  Future<void> _loadZone() async {
    final id = selectedCamera.value?.id;
    if (id == null) return;
    try {
      final res = await _client
          .get(Uri.parse(ApisUrl.safeZoneGet(id)), headers: {'bypass-tunnel-reminder': 'true'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pts = data['points'] as List?;
        if (pts != null) {
          zonePoints.assignAll(pts.map<Offset>((p) {
            if (p is List && p.length >= 2) {
              return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
            }
            if (p is Map) {
              return Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());
            }
            return Offset.zero;
          }).toList());
        }
      }
    } catch (_) {
      // Non-fatal — zone na mile to khali polygon
    }
  }

  void startDrawingZone() {
    zoom.value = 1.0; // 1x par draw karo taake coords frame se match karein
    isDrawingZone.value = true;
  }

  void cancelDrawingZone() {
    isDrawingZone.value = false;
    _loadZone(); // saved zone par wapas
  }

  void addZonePoint(Offset normalized) {
    if (!isDrawingZone.value) return;
    zonePoints.add(normalized);
  }

  void undoZonePoint() {
    if (zonePoints.isNotEmpty) zonePoints.removeLast();
  }

  void clearZonePoints() => zonePoints.clear();

  /// Polygon backend par save karo (web jaisा — normalized {x,y}).
  Future<void> saveZone() async {
    final id = selectedCamera.value?.id;
    if (id == null) return;
    if (zonePoints.length < 3) {
      SnackBarUtils.showError('At least 3 points needed to define a zone.', title: 'Safe Zone');
      return;
    }
    isZoneSaving.value = true;
    try {
      final body = jsonEncode({
        'camera_id': id.toString(),
        'points': zonePoints.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      });
      final res = await _client
          .post(
            Uri.parse(ApisUrl.safeZoneSet),
            headers: {'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true'},
            body: body,
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        isDrawingZone.value = false;
        SnackBarUtils.showSnackBar(
          'Restricted zone saved for ${selectedCamera.value?.name ?? 'camera'}.',
          title: 'Safe Zone Set',
        );
      } else {
        SnackBarUtils.showError('Server returned ${res.statusCode}', title: 'Safe Zone Failed');
      }
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Safe Zone Failed');
    } finally {
      isZoneSaving.value = false;
    }
  }

  /// Zone backend se hata do.
  Future<void> clearZone() async {
    final id = selectedCamera.value?.id;
    if (id == null) return;
    try {
      await _client
          .delete(Uri.parse(ApisUrl.safeZoneClear(id)), headers: {'bypass-tunnel-reminder': 'true'})
          .timeout(const Duration(seconds: 8));
      zonePoints.clear();
      isDrawingZone.value = false;
      SnackBarUtils.showSnackBar('Restricted zone removed.', title: 'Safe Zone Cleared');
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Error');
    }
  }

  bool get hasDetection => false;

  @override
  void onClose() {
    _clockTimer?.cancel();
    _frameTimer?.cancel();
    _client.close();
    // Agar fullscreen mein chhod kar gaye to portrait restore kar do
    _exitFullscreen();
    super.onClose();
  }
}
