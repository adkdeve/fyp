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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return OverflowBox(
                        minWidth: 0,
                        minHeight: 0,
                        maxWidth: constraints.maxHeight,
                        maxHeight: constraints.maxWidth,
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 0,
                            child: SizedBox(
                              width: constraints.maxHeight,
                              height: constraints.maxWidth,
                              child: Image.memory(
                                bytes,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
}
