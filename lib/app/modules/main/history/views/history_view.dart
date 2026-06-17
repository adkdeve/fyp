import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../../common/widgets/my_text.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import 'package:construction_safety/common/widgets/app_header.dart';
import '../../../../data/models/violation_model.dart';
import '../controllers/history_controller.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

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
                title: 'Violation History',
                subtitle: 'Complete safety incident log',
                actions: [
                  IconButton(
                    onPressed: controller.exportData,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                  ),
                ],
                bottom: Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                  ],
                ),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: controller.searchController,
      onChanged: controller.setSearchTerm,
      decoration: InputDecoration(
        hintText: 'Search violations...',
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
        backgroundColor: AppColor.subtleBg,
        selectedColor: Colors.blue[100],
        labelStyle: TextStyle(color: isSelected ? Colors.blue[700] : AppColor.textSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      );
    });
  }

  Widget _buildContent() {
    return Obx(() {
      final filteredData = controller.filteredData;

      if (filteredData.isEmpty && !controller.isLoading.value) {
        return _buildEmptyState();
      }

      // 🟢 Attached ScrollController and added Loading Indicator at the bottom
      return ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredData.length + (controller.hasMore.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < filteredData.length) {
            return _buildViolationCard(filteredData[index]);
          } else {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
        },
      );
    });
  }

  Widget _buildViolationCard(ViolationModel violation) {
    // 🟢 Optimization: Removed custom class instances allocation. Directly fetching values.
    final statusBgColor = _getStatusBgColor(violation.status);
    final statusTextColor = _getStatusTextColor(violation.status);
    final statusLabel = _getStatusLabel(violation.status);

    final severityBgColor = _getSeverityBgColor(violation.severity);
    final severityTextColor = _getSeverityTextColor(violation.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColor.subtleBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    violation.type.name,
                    style: TextStyle(fontSize: 12, color: AppColor.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: severityBgColor, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    violation.severity.name.toUpperCase(),
                    style: TextStyle(fontSize: 12, color: severityTextColor, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 12, color: statusTextColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              violation.description,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
            ),
            const SizedBox(height: 12),
            _buildDetailsRow(violation),
            if (violation.acknowledgedBy != null) ...[
              const SizedBox(height: 8),
              Text(
                'Acknowledged by: ${violation.acknowledgedBy}',
                style: TextStyle(fontSize: 12, color: Colors.green[600], fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 12),
            _buildViewDetailsButton(violation),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsRow(ViolationModel violation) {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildDetailItem(Icons.location_on, violation.zone)),
        const SizedBox(width: 8),
        Expanded(flex: 1, child: _buildDetailItem(Icons.calendar_today, controller.formatDate(violation.time))),
        const SizedBox(width: 8),
        Expanded(flex: 1, child: _buildDetailItem(Icons.access_time, controller.formatTime(violation.time))),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColor.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: MyText(
            text: text,
            fontSize: 12,
            color: AppColor.textSecondary,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
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
          foregroundColor: AppColor.textSecondary,
          backgroundColor: AppColor.subtleBg,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: AppColor.borderColor),
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
            decoration: BoxDecoration(color: AppColor.subtleBg, shape: BoxShape.circle),
            child: Icon(Icons.filter_list, size: 32, color: AppColor.textTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
          ),
          const SizedBox(height: 8),
          Text('Try adjusting your filters or search term', style: TextStyle(color: AppColor.textSecondary)),
        ],
      ),
    );
  }

  // Theme-aware badge colors (light tint in light mode, dark tint in dark mode).
  Color _statusBase(ViolationStatus status) {
    switch (status) {
      case ViolationStatus.resolved:
        return Colors.green;
      case ViolationStatus.acknowledged:
        return Colors.amber;
      case ViolationStatus.dismissed:
        return Colors.grey;
      case ViolationStatus.active:
        return Colors.red;
    }
  }

  Color _getStatusBgColor(ViolationStatus status) => AppColor.accentBadgeBg(_statusBase(status));

  Color _getStatusTextColor(ViolationStatus status) => AppColor.accentText(_statusBase(status));

  String _getStatusLabel(ViolationStatus status) {
    switch (status) {
      case ViolationStatus.resolved:
        return 'Resolved';
      case ViolationStatus.acknowledged:
        return 'Acknowledged';
      case ViolationStatus.dismissed:
        return 'Dismissed';
      case ViolationStatus.active:
        return 'Active';
    }
  }

  Color _severityBase(ViolationSeverity severity) {
    switch (severity) {
      case ViolationSeverity.high:
        return Colors.red;
      case ViolationSeverity.medium:
        return Colors.orange;
      case ViolationSeverity.low:
        return Colors.blue;
    }
  }

  Color _getSeverityBgColor(ViolationSeverity severity) => AppColor.accentBadgeBg(_severityBase(severity));

  Color _getSeverityTextColor(ViolationSeverity severity) => AppColor.accentText(_severityBase(severity));
}
