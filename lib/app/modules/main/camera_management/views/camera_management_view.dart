import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../controllers/camera_management_controller.dart';

class CameraManagementView extends GetView<CameraManagementController> {
  const CameraManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              // Header
              _buildHeader(),
              // Content
              Expanded(child: _buildCameraList()),
            ],
          ),
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
          // Back button and title
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
                    Obx(
                      () => Text(
                        '${controller.cameras.length} cameras configured',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchAndFilters(),
          const SizedBox(height: 16),
          // Stats
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          controller: controller.searchController,
          decoration: InputDecoration(
            hintText: 'Search cameras...',
            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Obx(
            () => Row(
              children: [
                _statusChip('All', 'all'),
                const SizedBox(width: 8),
                _statusChip('Online', 'online'),
                const SizedBox(width: 8),
                _statusChip('Offline', 'offline'),
                const SizedBox(width: 8),
                _statusChip('Error', 'error'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String label, String value) {
    final selected = controller.statusFilter.value == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => controller.setStatusFilter(value),
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: selected ? Colors.blue[700] : Colors.grey[600],
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  Widget _buildStats() {
    return Obx(() {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Enabled',
              '${controller.enabledCount}',
              Colors.blue[50]!,
              Colors.blue[200]!,
              Colors.blue[700]!,
            ),
          ),
          const SizedBox(width: 8),
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
              'Disabled',
              '${controller.disabledCount}',
              Colors.red[50]!,
              Colors.red[200]!,
              Colors.red[700]!,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color bgColor,
    Color borderColor,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: textColor)),
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
        itemCount: controller.filteredCameras.length,
        itemBuilder: (context, index) {
          return _buildCameraCard(controller.filteredCameras[index]);
        },
      );
    });
  }

  Widget _buildCameraCard(CameraModel camera) {
    return Obx(() {
      final isOnline =
          camera.enabled && camera.status.toLowerCase() == "online";

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
                                    color: isOnline
                                        ? Colors.green[600]
                                        : Colors.red[600],
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
              _buildCameraPreview(camera),
              const SizedBox(height: 12),
              // Controls
              _buildCameraControls(camera, isOnline),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCameraPreview(CameraModel camera) {
    return GestureDetector(
      onTap: camera.enabled ? () => controller.handleViewFeed(camera) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: camera.enabled ? Colors.blueGrey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              camera.enabled ? Icons.videocam : Icons.videocam_off,
              size: 28,
              color: camera.enabled ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.enabled
                        ? 'Live monitoring is available for this camera.'
                        : 'This camera is currently excluded from monitoring.',
                    style: TextStyle(
                      color: camera.enabled ? Colors.white : Colors.grey[800],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    camera.enabled
                        ? 'Open the feed to inspect the latest frames and take snapshots.'
                        : 'Enable it to make it visible on the dashboard and eligible for alert storage.',
                    style: TextStyle(
                      color: camera.enabled
                          ? Colors.white70
                          : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControls(CameraModel camera, bool isOnline) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: camera.enabled
                ? () => controller.handleViewFeed(camera)
                : null,
            icon: Icon(
              Icons.open_in_new,
              size: 16,
              color: camera.enabled ? Colors.blue[700] : Colors.grey,
            ),
            label: Text(
              'Open Feed',
              style: TextStyle(
                color: camera.enabled ? Colors.blue[700] : Colors.grey[700],
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: camera.enabled
                  ? Colors.blue[50]
                  : Colors.grey[50],
              foregroundColor: camera.enabled
                  ? Colors.blue[700]
                  : Colors.grey[700],
              side: BorderSide(
                color: camera.enabled ? Colors.blue[200]! : Colors.grey[200]!,
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
              camera.enabled ? 'Disable' : 'Enable',
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
