import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import 'package:construction_safety/common/widgets/app_header.dart';
import '../../../../data/models/camera_model.dart';
import '../controllers/camera_management_controller.dart';

class CameraManagementView extends GetView<CameraManagementController> {
  const CameraManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColor.statusBar,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: AppColor.scaffoldBg,
          body: Column(
            children: [
              AppHeader(
                title: 'Camera Management',
                subtitle: 'Manage and monitor your site cameras',
                showBack: true,
                bottom: Column(
                  children: [
                    _buildSearchAndFilters(),
                    const SizedBox(height: 16),
                    _buildStats(),
                  ],
                ),
              ),
              Expanded(child: _buildCameraList()),
            ],
          ),
        ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.borderColor),
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
      backgroundColor: AppColor.subtleBg,
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(color: selected ? Colors.blue[700] : AppColor.textSecondary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  Widget _buildStats() {
    return Obx(() {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard('Enabled', '${controller.enabledCount}', Colors.blue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Online', '${controller.onlineCount}', Colors.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Disabled', '${controller.disabledCount}', Colors.red),
          ),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, Color base) {
    final textColor = AppColor.accentText(base);
    return Container(
      decoration: BoxDecoration(
        color: AppColor.tintedSurface(base),
        border: Border.all(color: AppColor.accentBorder(base)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: textColor)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
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
    final isOnline = camera.enabled && camera.status.toLowerCase() == "online";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.borderColor),
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
                    color: isOnline ? AppColor.accentBadgeBg(Colors.green) : AppColor.accentBadgeBg(Colors.red),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt,
                      color: isOnline ? AppColor.accentText(Colors.green) : AppColor.accentText(Colors.red), size: 20),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
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
                                style: TextStyle(fontSize: 12, color: isOnline ? Colors.green[600] : Colors.red[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(camera.zone, style: TextStyle(fontSize: 14, color: AppColor.textSecondary)),
                      const SizedBox(height: 2),
                      Text('ID: ${camera.id}', style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
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
                    style: TextStyle(color: camera.enabled ? Colors.white70 : Colors.grey[700], fontSize: 12),
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
            onPressed: camera.enabled ? () => controller.handleViewFeed(camera) : null,
            icon: Icon(Icons.open_in_new, size: 16, color: camera.enabled ? Colors.blue[700] : Colors.grey),
            label: Text('Open Feed', style: TextStyle(color: camera.enabled ? Colors.blue[700] : Colors.grey[700])),
            style: ElevatedButton.styleFrom(
              backgroundColor: camera.enabled ? Colors.blue[50] : Colors.grey[50],
              foregroundColor: camera.enabled ? Colors.blue[700] : Colors.grey[700],
              side: BorderSide(color: camera.enabled ? Colors.blue[200]! : Colors.grey[200]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              style: TextStyle(color: isOnline ? Colors.green[700] : Colors.red[700]),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOnline ? Colors.green[50] : Colors.red[50],
              foregroundColor: isOnline ? Colors.green[700] : Colors.red[700],
              side: BorderSide(color: isOnline ? Colors.green[200]! : Colors.red[200]!),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
