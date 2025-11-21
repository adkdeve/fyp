import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../controllers/camera_management_controller.dart';

class CameraManagementView extends GetView<CameraManagementController> {
  const CameraManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            // Header
            _buildHeader(),
            // Content
            Expanded(
              child: _buildCameraList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Back button, title, and add button
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Camera Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Obx(() => Text(
                      '${controller.cameras.length} cameras configured',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.handleAddCamera,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Obx(() {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Online',
              '${controller.onlineCount}',
              Colors.green[50]!,
              Colors.green[200]!,
              Colors.green[700]!,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Recording',
              '${controller.recordingCount}',
              Colors.blue[50]!,
              Colors.blue[200]!,
              Colors.blue[700]!,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Offline',
              '${controller.offlineCount}',
              Colors.red[50]!,
              Colors.red[200]!,
              Colors.red[700]!,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, Color bgColor, Color borderColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraList() {
    return Obx(() {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: controller.cameras.length,
        itemBuilder: (context, index) {
          return _buildCameraCard(controller.cameras[index]);
        },
      );
    });
  }

  Widget _buildCameraCard(CameraModel camera) {
    return Obx(() {
      final isOnline = camera.status.toLowerCase() == "online";
      final isRecording = controller.isRecording(camera.id);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Camera header
              Row(
                children: [
                  // Camera icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: isOnline ? Colors.green[600] : Colors.red[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Camera info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              camera.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnline ? 'online' : 'offline',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOnline ? Colors.green[600] : Colors.red[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          camera.zone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${camera.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Camera preview
              _buildCameraPreview(camera, isRecording),
              const SizedBox(height: 12),
              // Controls
              _buildCameraControls(camera, isOnline, isRecording),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCameraPreview(CameraModel camera, bool isRecording) {
    return GestureDetector(
      onTap: () => controller.handleViewFeed(camera),
      child: Container(
        width: double.infinity,
        height: 128,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Grid pattern background
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.grey, Colors.black87],
                ),
              ),
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),
            // Center icon
            const Center(
              child: Icon(
                Icons.videocam,
                size: 32,
                color: Colors.white54,
              ),
            ),
            // Recording indicator
            if (isRecording) ...[
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 4),
                      const Text(
                        'REC',
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControls(CameraModel camera, bool isOnline, bool isRecording) {
    return Row(
      children: [
        // Recording button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isOnline ? () => controller.toggleRecording(camera.id) : null,
            icon: Icon(
              Icons.circle,
              size: 16,
              color: isRecording ? Colors.red : Colors.grey,
            ),
            label: Text(
              isRecording ? 'Stop Recording' : 'Start Recording',
              style: TextStyle(
                color: isRecording ? Colors.red[700] : Colors.grey[700],
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRecording ? Colors.red[50] : Colors.grey[50],
              foregroundColor: isRecording ? Colors.red[700] : Colors.grey[700],
              side: BorderSide(
                color: isRecording ? Colors.red[200]! : Colors.grey[200]!,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Enable/Disable button
        Expanded(
          child: ElevatedButton(
            onPressed: () => controller.toggleStatus(camera.id),
            child: Text(
              isOnline ? 'Disable' : 'Enable',
              style: TextStyle(
                color: isOnline ? Colors.green[700] : Colors.red[700],
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOnline ? Colors.green[50] : Colors.red[50],
              foregroundColor: isOnline ? Colors.green[700] : Colors.red[700],
              side: BorderSide(
                color: isOnline ? Colors.green[200]! : Colors.red[200]!,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for the grid pattern
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
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