import 'package:construction_safety/common/widgets/build_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../data/models/violation_model.dart';
import '../controllers/violation_detail_controller.dart';

class ViolationDetailView extends GetView<ViolationDetailController> {
  const ViolationDetailView({super.key});

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
          body: Obx(() {
            final violation = controller.selectedViolation.value;
            if (violation == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final config = controller.getSeverityConfig(violation.severity);
            final recommendedActions = controller.getRecommendedActions(violation.type);

            return Column(
              children: [
                // Header
                _buildHeader(),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Severity Banner
                        _buildSeverityBanner(violation, config),
                        const SizedBox(height: 16),
                        // Evidence Photo
                        _buildEvidencePhoto(context, violation),
                        const SizedBox(height: 16),
                        // Location & Time Info
                        _buildIncidentInfo(violation),
                        const SizedBox(height: 16),
                        // Recommended Actions
                        _buildRecommendedActions(recommendedActions),
                        const SizedBox(height: 16),
                        // Action Buttons
                        _buildActionButtons(violation),
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

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() {
              final violation = controller.selectedViolation.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Violation Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  Text('ID: ${violation?.id ?? ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBanner(ViolationModel violation, Map<String, dynamic> config) {
    return Container(
      decoration: BoxDecoration(
        color: config['bg'] as Color,
        border: Border(left: BorderSide(color: config['border'] as Color, width: 4)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: config['text'] as Color, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: config['badge'] as Color, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${violation.severity.name.toUpperCase()} PRIORITY',
                  style: TextStyle(color: config['text'] as Color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            violation.description,
            style: TextStyle(color: config['text'] as Color, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('Type: ${violation.type.name} Violation', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEvidencePhoto(BuildContext context, ViolationModel violation) {
    final imageUrl = violation.imageUrl;
    final confidenceText = violation.confidence != null
        ? 'AI Detection Confidence: ${(violation.confidence! * 100).toStringAsFixed(0)}%'
        : 'AI Detection Confidence: N/A';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.grey[700]),
              const SizedBox(width: 8),
              const Text(
                'Visual Evidence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: imageUrl != null
                  ? buildImage(imageUrl, fit: BoxFit.cover, context: context)
                  : _noSnapshotPlaceholder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(confidenceText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _noSnapshotPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.white38, size: 40),
          SizedBox(height: 8),
          Text('No snapshot available', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildIncidentInfo(ViolationModel violation) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Incident Information',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildInfoItem(
                icon: Icons.location_on,
                iconColor: Colors.blue,
                iconBgColor: Colors.blue[100]!,
                title: 'Location',
                value: violation.zone,
              ),
              _buildInfoItem(
                icon: Icons.access_time,
                iconColor: Colors.purple,
                iconBgColor: Colors.purple[100]!,
                title: 'Time Detected',
                value: _formatTime(violation.time),
              ),
              _buildInfoItem(
                icon: Icons.calendar_today,
                iconColor: Colors.green,
                iconBgColor: Colors.green[100]!,
                title: 'Date',
                value: _formatDate(violation.time),
              ),
              _buildInfoItem(
                icon: Icons.camera_alt,
                iconColor: Colors.orange,
                iconBgColor: Colors.orange[100]!,
                title: 'Camera Source',
                value: violation.cameraId != null ? 'CAM-${violation.cameraId.toString().padLeft(3, '0')}' : 'Unknown',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedActions(List<String> actions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Column(
            children: actions
                .map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(action, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ViolationModel violation) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.handleDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download Report'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.handleShare,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
        if (violation.status == ViolationStatus.active) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: controller.handleResolve,
            icon: const Icon(Icons.check_circle),
            label: const Text('Mark as Resolved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}
