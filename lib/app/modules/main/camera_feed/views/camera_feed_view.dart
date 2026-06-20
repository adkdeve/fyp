import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../data/models/camera_model.dart';
import '../controllers/camera_feed_controller.dart';

class CameraFeedView extends GetView<CameraFeedController> {
  const CameraFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Obx(() {
            final camera = controller.selectedCamera.value;
            if (camera == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final isOnline = camera.cameraStatus == CameraStatus.online;
            return Column(
              children: [
                _buildHeader(camera, isOnline),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildLiveFeed(),
                        const SizedBox(height: 12),
                        _buildZoneControls(),
                        const SizedBox(height: 16),
                        _buildZoomControls(),
                        const SizedBox(height: 16),
                        _buildCameraInfo(camera),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeader(CameraModel camera, bool isOnline) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      camera.zone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF00FF00) : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    camera.status,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? const Color(0xFF00FF00) : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickControls(),
        ],
      ),
    );
  }

  Widget _buildQuickControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Live Monitoring', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: controller.takeSnapshot,
          icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
          label: const Text('Snapshot', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2A2A2A),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveFeed() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Obx(() {
            final bytes = controller.frameBytes.value;
            final loading = controller.isStreamLoading.value;
            final error = controller.streamError.value;

            if (loading && bytes == null) {
              return _buildPlaceholder(
                icon: Icons.videocam,
                message: 'Connecting to stream...',
                showSpinner: true,
              );
            }

            if (error && bytes == null) {
              return _buildPlaceholder(
                icon: Icons.signal_wifi_off,
                message: 'Stream unavailable',
                showSpinner: false,
              );
            }

            if (bytes != null) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Poora frame landscape mein fit (cut nahi) + zoom apply
                  Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Obx(
                      () => Transform.scale(
                        scale: controller.zoom.value,
                        child: Image.memory(
                          bytes,
                          gaplessPlayback: true,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(top: 10, left: 10, child: _liveBadge()),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Obx(
                      () => _hudChip(controller.currentTime.value),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Obx(
                      () => _hudChip(
                        '${controller.zoom.value.toStringAsFixed(1)}x',
                      ),
                    ),
                  ),
                  // Safe zone polygon overlay + draw taps
                  Positioned.fill(child: _zoneOverlay()),
                ],
              );
            }

            return _buildPlaceholder(
              icon: Icons.videocam_off,
              message: 'No signal',
              showSpinner: false,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({
    required IconData icon,
    required String message,
    required bool showSpinner,
  }) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSpinner)
            const CircularProgressIndicator(color: Color(0xFF3B82F6))
          else
            Icon(icon, size: 48, color: const Color(0xFF444444)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFCC0000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Camera Controls',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final zoom = controller.zoom.value;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _controlBtn(
                  Icons.zoom_in,
                  'Zoom In',
                  controller.zoomIn,
                  zoom < 3.0,
                ),
                _controlBtn(
                  Icons.zoom_out,
                  'Zoom Out',
                  controller.zoomOut,
                  zoom > 1.0,
                ),
                _controlBtn(Icons.refresh, 'Reset', controller.resetZoom, true),
                _controlBtn(
                  Icons.fullscreen,
                  'Fullscreen',
                  controller.enterFullscreen,
                  true,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _controlBtn(
    IconData icon,
    String label,
    VoidCallback onPressed,
    bool enabled,
  ) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled
            ? const Color(0xFF2A2A2A)
            : const Color(0xFF1A1A1A),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: enabled ? Colors.white : const Color(0xFF666666),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: enabled ? Colors.white : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraInfo(CameraModel camera) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Camera Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow('Camera ID:', '#${camera.id}'),
          _infoRow('Location:', camera.zone),
          _infoRow('Frame Rate:', '${camera.fpsTarget} FPS'),
          _infoRow(
            'AI Detection:',
            camera.enabled ? 'Active' : 'Inactive',
            isActive: camera.enabled,
          ),
          _infoRow('Feed Mode:', 'Backend live frames'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: isActive ? const Color(0xFF00FF00) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Safe Zone overlay + controls ─────────────────────────────────────────────
  Widget _zoneOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Obx(() {
          final drawing = controller.isDrawingZone.value;
          final pts = controller.zonePoints.toList();
          return GestureDetector(
            behavior: drawing ? HitTestBehavior.opaque : HitTestBehavior.translucent,
            onTapDown: drawing
                ? (d) {
                    controller.addZonePoint(
                      Offset(
                        (d.localPosition.dx / size.width).clamp(0.0, 1.0),
                        (d.localPosition.dy / size.height).clamp(0.0, 1.0),
                      ),
                    );
                  }
                : null,
            child: CustomPaint(
              size: size,
              painter: ZonePainter(points: pts, drawing: drawing),
            ),
          );
        });
      },
    );
  }

  Widget _buildZoneControls() {
    return Obx(() {
      final drawing = controller.isDrawingZone.value;
      final hasPoints = controller.zonePoints.isNotEmpty;

      if (!drawing) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: controller.startDrawingZone,
                icon: const Icon(Icons.gesture, size: 16, color: Colors.white),
                label: Text(
                  hasPoints ? 'Edit Safe Zone' : 'Draw Safe Zone',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (hasPoints) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: controller.clearZone,
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                label: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF333333)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            ],
          ],
        );
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2563EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.draw, size: 16, color: Color(0xFF3B82F6)),
                SizedBox(width: 6),
                Text(
                  'Draw Restricted Zone',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Obx(() {
              final n = controller.zonePoints.length;
              final msg = n < 3
                  ? 'Tap on the feed to place points (${3 - n} more needed)'
                  : '$n-point zone — tap Save to confirm';
              return Text(msg, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12));
            }),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _zoneToolBtn(Icons.undo, 'Undo', controller.undoZonePoint),
                _zoneToolBtn(Icons.clear, 'Clear', controller.clearZonePoints),
                _zoneToolBtn(Icons.close, 'Cancel', controller.cancelDrawingZone),
                Obx(
                  () => ElevatedButton.icon(
                    onPressed: controller.isZoneSaving.value ? null : controller.saveZone,
                    icon: controller.isZoneSaving.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 16, color: Colors.white),
                    label: const Text('Save', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _zoneToolBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Camera frame ke upar restricted-zone polygon draw karta hai (normalized points).
class ZonePainter extends CustomPainter {
  final List<Offset> points; // normalized 0..1
  final bool drawing;

  ZonePainter({required this.points, required this.drawing});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final pix = points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

    final fill = Paint()
      ..color = const Color(0x383B82F6)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path()..moveTo(pix.first.dx, pix.first.dy);
    for (var i = 1; i < pix.length; i++) {
      path.lineTo(pix[i].dx, pix[i].dy);
    }
    if (pix.length >= 3) {
      path.close();
      canvas.drawPath(path, fill);
    }
    canvas.drawPath(path, stroke);

    // Vertex dots (pehla dot cyan = closing point)
    for (var i = 0; i < pix.length; i++) {
      final r = i == 0 ? 7.0 : 5.0;
      canvas.drawCircle(pix[i], r, Paint()..color = i == 0 ? const Color(0xFF06B6D4) : const Color(0xFF3B82F6));
      canvas.drawCircle(
        pix[i],
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // "RESTRICTED ZONE" label center mein
    if (pix.length >= 3) {
      final cx = pix.map((p) => p.dx).reduce((a, b) => a + b) / pix.length;
      final cy = pix.map((p) => p.dy).reduce((a, b) => a + b) / pix.length;
      final tp = TextPainter(
        text: const TextSpan(
          text: 'RESTRICTED ZONE',
          style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(ZonePainter old) => old.points != points || old.drawing != drawing;
}
