import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../../common/widgets/my_text.dart';
import '../../../../data/models/violation_model.dart';
import '../controllers/history_controller.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

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
              // Header Section
              _buildHeader(),
              // Content Section
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Title and Export Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Violation History',
                    style: Get.textTheme.titleLarge?.copyWith(color: Colors.grey[900], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete safety incident log',
                    style: Get.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              IconButton(
                onPressed: controller.exportData,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(2),
                ),
                icon: const Icon(Icons.download_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar
          _buildSearchBar(),
          const SizedBox(height: 12),
          // Filter Chips
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: controller.searchController,
      decoration: InputDecoration(
        hintText: 'Search violations...',
        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', null),
          const SizedBox(width: 8),
          _buildFilterChip('PPE', ViolationType.PPE),
          const SizedBox(width: 8),
          _buildFilterChip('Unauthorized', ViolationType.Unauthorized),
          const SizedBox(width: 8),
          _buildFilterChip('Hazardous', ViolationType.Hazardous),
          const SizedBox(width: 8),
          _buildFilterChip('Material', ViolationType.Material),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ViolationType? type) {
    return Obx(() {
      final isSelected = controller.filterType.value == type;
      return FilterChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) => controller.setFilterType(isSelected ? null : type),
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.blue[100],
        labelStyle: TextStyle(color: isSelected ? Colors.blue[700] : Colors.grey[600], fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      );
    });
  }

  Widget _buildContent() {
    return Obx(() {
      final filteredData = controller.filteredData;

      if (filteredData.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredData.length,
        itemBuilder: (context, index) {
          return _buildViolationCard(filteredData[index]);
        },
      );
    });
  }

  Widget _buildViolationCard(ViolationModel violation) {
    final statusStyle = _getStatusStyle(violation.status);
    final severityStyle = _getSeverityStyle(violation.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type, Severity and Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    violation.type.name,
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    violation.severity.name.toUpperCase(),
                    style: TextStyle(fontSize: 12, color: severityStyle.textColor, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusStyle.label,
                    style: TextStyle(fontSize: 12, color: statusStyle.textColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              violation.description,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            // Details Row
            _buildDetailsRow(violation),
            if (violation.acknowledgedBy != null) ...[
              const SizedBox(height: 8),
              Text(
                'Acknowledged by: ${violation.acknowledgedBy}',
                style: TextStyle(fontSize: 12, color: Colors.green[600], fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 12),
            // View Details Button
            _buildViewDetailsButton(violation),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsRow(ViolationModel violation) {
    return Row(
      children: [
        Expanded(
          flex: 2, // Give more space to zone since it's usually longer
          child: _buildDetailItem(Icons.location_on, violation.zone),
        ),
        const SizedBox(width: 8), // Reduced spacing
        Expanded(flex: 1, child: _buildDetailItem(Icons.calendar_today, controller.formatDate(violation.time))),
        const SizedBox(width: 8), // Reduced spacing
        Expanded(flex: 1, child: _buildDetailItem(Icons.access_time, controller.formatTime(violation.time))),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Take only minimum required space
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          // Allow text to wrap if needed
          child: MyText(
            text: text,
            fontSize: 12,
            color: Colors.grey[600],
            softWrap: false, // Prevent text wrapping
            overflow: TextOverflow.ellipsis, // Show ... if text is too long
          ),
        ),
      ],
    );
  }

  Widget _buildViewDetailsButton(ViolationModel violation) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => controller.viewViolationDetails(violation),
        icon: const Icon(Icons.remove_red_eye, size: 16),
        label: const Text('View Full Report'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          backgroundColor: Colors.grey[50],
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.grey[200]!),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(Icons.filter_list, size: 32, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[900]),
          ),
          const SizedBox(height: 8),
          Text('Try adjusting your filters or search term', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  _StatusStyle _getStatusStyle(ViolationStatus status) {
    switch (status) {
      case ViolationStatus.resolved:
        return _StatusStyle(backgroundColor: Colors.green[100]!, textColor: Colors.green[700]!, label: 'Resolved');
      case ViolationStatus.acknowledged:
        return _StatusStyle(
          backgroundColor: Colors.yellow[100]!,
          textColor: Colors.yellow[700]!,
          label: 'Acknowledged',
        );
      case ViolationStatus.dismissed:
        return _StatusStyle(backgroundColor: Colors.grey[100]!, textColor: Colors.grey[700]!, label: 'Dismissed');
      case ViolationStatus.active:
        return _StatusStyle(backgroundColor: Colors.red[100]!, textColor: Colors.red[700]!, label: 'Active');
    }
  }

  _StatusStyle _getSeverityStyle(ViolationSeverity severity) {
    switch (severity) {
      case ViolationSeverity.high:
        return _StatusStyle(backgroundColor: Colors.red[100]!, textColor: Colors.red[700]!, label: 'HIGH');
      case ViolationSeverity.medium:
        return _StatusStyle(backgroundColor: Colors.orange[100]!, textColor: Colors.orange[700]!, label: 'MEDIUM');
      case ViolationSeverity.low:
        return _StatusStyle(backgroundColor: Colors.blue[100]!, textColor: Colors.blue[700]!, label: 'LOW');
    }
  }
}

class _StatusStyle {
  final Color backgroundColor;
  final Color textColor;
  final String label;

  _StatusStyle({required this.backgroundColor, required this.textColor, required this.label});
}
