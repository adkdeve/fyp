import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/core.dart';
import '../../../../data/models/camera_model.dart';
import '../controllers/camera_feed_controller.dart';

class CameraFeedView extends GetView<CameraFeedController> {
  const CameraFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
          statusBarIconBrightness: Brightness.light,
          statusBarColor: const Color(0xFF0F0F0F)
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F), // Darker background like in image
          body: SafeArea(
            child: Obx(() {
              final camera = controller.selectedCamera.value;
              if (camera == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final isOnline = camera.cameraStatus == CameraStatus.online;

              return Column(
                children: [
                  // Header
                  _buildHeader(camera, isOnline),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Live Feed
                          _buildLiveFeed(camera, context, isOnline),
                          const SizedBox(height: 16),
                          // Zoom Controls
                          _buildZoomControls(),
                          const SizedBox(height: 16),
                          // Camera Info
                          _buildCameraInfo(),
                          const SizedBox(height: 16),
                          // Download Button
                          _buildDownloadButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CameraModel camera, bool isOnline) {
    return Container(
      color: const Color(0xFF1A1A1A), // Dark header background
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Back button and camera info
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
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
                        color: Color(0xFFAAAAAA), // Lighter grey for zone
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
                      color: isOnline ? const Color(0xFF00FF00) : Colors.red, // Bright green for online
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    camera.status,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? const Color(0xFF00FF00) : Colors.red, // Bright green for online
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick Controls
          _buildQuickControls(),
        ],
      ),
    );
  }

  Widget _buildQuickControls() {
    return Obx(() {
      final isRecording = controller.isRecording.value;

      return Row(
        children: [
          // Recording Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: controller.toggleRecording,
              icon: Icon(
                Icons.circle,
                size: 16,
                color: isRecording ? Colors.white : const Color(0xFF666666),
              ),
              label: Text(
                isRecording ? 'Recording' : 'Start Recording',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording ? const Color(0xFFFF0000) : const Color(0xFF2A2A2A), // Bright red for recording
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Slightly less rounded
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Snapshot Button
          ElevatedButton.icon(
            onPressed: controller.takeSnapshot,
            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            label: const Text('Snapshot', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A2A), // Dark grey button
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildLiveFeed(CameraModel camera, BuildContext context, bool isOnline) {
    return Obx(() {
      final hasDetection = controller.hasDetection;
      final currentTime = controller.currentTime.value;
      final zoomLevel = controller.zoom.value;

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12), // Slightly less rounded
          border: Border.all(color: const Color(0xFF333333), width: 1), // Dark border
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              // Solid black background (no gradient)
              Container(
                color: Colors.black,
                child: CustomPaint(
                  painter: _GridPainter(),
                ),
              ),

              // LIVE FEED indicator
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000), // Bright red
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
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE FEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Timestamp
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7), // Darker background
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),

              // Zoom Level
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7), // Darker background
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${zoomLevel}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),

              // Detection Overlay (for CAM-002)
              if (hasDetection) ...[
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.33,
                  left: MediaQuery.of(context).size.width * 0.25,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -24,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PPE Violation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Camera Icon in center
              const Center(
                child: Icon(
                  Icons.videocam,
                  size: 64,
                  color: Color(0xFF333333), // Darker grey icon
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Dark background
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
                _buildControlButton(
                  icon: Icons.zoom_in,
                  label: 'Zoom In',
                  onPressed: controller.zoomIn,
                  enabled: zoom < 3.0,
                ),
                _buildControlButton(
                  icon: Icons.zoom_out,
                  label: 'Zoom Out',
                  onPressed: controller.zoomOut,
                  enabled: zoom > 1.0,
                ),
                _buildControlButton(
                  icon: Icons.refresh,
                  label: 'Reset',
                  onPressed: controller.resetZoom,
                  enabled: true,
                ),
                _buildControlButton(
                  icon: Icons.fullscreen,
                  label: 'Fullscreen',
                  onPressed: controller.enterFullscreen,
                  enabled: true,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool enabled,
  }) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A), // Dark grey for enabled
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: enabled ? Colors.white : const Color(0xFF666666)),
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

  Widget _buildCameraInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Dark background
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
          Column(
            children: [
              _buildInfoRow('Resolution:', '1920x1080 (Full HD)'),
              _buildInfoRow('Frame Rate:', '30 FPS'),
              _buildInfoRow('AI Detection:', 'Active', isActive: true),
              _buildInfoRow('Storage:', 'Cloud + Local'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFAAAAAA), // Lighter grey for labels
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isActive ? const Color(0xFF00FF00) : Colors.white, // Bright green for active
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return ElevatedButton.icon(
      onPressed: controller.downloadRecording,
      icon: const Icon(Icons.download, color: Colors.white),
      label: const Text('Download Recording', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB), // Bright blue like in image
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// Grid Painter with adjusted colors
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333).withOpacity(0.3) // Darker grid lines
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const cellSize = 20.0;
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();

    // Draw vertical lines
    for (var i = 0; i <= cols; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (var i = 0; i <= rows; i++) {
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}