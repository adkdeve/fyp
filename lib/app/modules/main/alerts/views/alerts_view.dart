import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import 'package:construction_safety/common/widgets/app_header.dart';
import '../controllers/alerts_controller.dart';
import '../../../../data/models/violation_model.dart';

class AlertsView extends GetView<AlertsController> {
  const AlertsView({super.key});

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
                title: 'Active Alerts',
                bottom: _searchAndFilters(),
              ),
              Expanded(
                child: Obx(() {
                  final activeAlerts = controller.activeAlerts;

                  return SingleChildScrollView(
                    controller: controller.scrollController,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _summaryCards(activeAlerts),
                        const SizedBox(height: 14),
                        if (activeAlerts.isEmpty) _noAlertWidget(),
                        if (activeAlerts.isNotEmpty) ...activeAlerts.map((alert) => _alertCard(alert)),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchAndFilters() {
    return Column(
      children: [
        TextField(
          controller: controller.searchController,
          onChanged: controller.setSearchTerm,
          decoration: InputDecoration(
            hintText: 'Search alerts...',
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
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Obx(() {
            return Row(
              children: [
                _filterChip('All', null),
                const SizedBox(width: 8),
                _filterChip('High', ViolationSeverity.high),
                const SizedBox(width: 8),
                _filterChip('Medium', ViolationSeverity.medium),
                const SizedBox(width: 8),
                _filterChip('Low', ViolationSeverity.low),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _filterChip(String label, ViolationSeverity? severity) {
    final selected = controller.severityFilter.value == severity;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => controller.setSeverityFilter(selected ? null : severity),
      backgroundColor: AppColor.subtleBg,
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(color: selected ? Colors.blue[700] : AppColor.textSecondary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    );
  }

  Widget _summaryCards(List<ViolationModel> activeAlerts) {
    return Row(
      children: [
        _severityCard(
          "High",
          Colors.red,
          controller.countBySeverity(ViolationSeverity.high), // 🟢 OPTIMIZED TO USE CONTROLLER METHOD
        ),
        _severityCard("Medium", Colors.orange, controller.countBySeverity(ViolationSeverity.medium)),
        _severityCard("Low", Colors.blue, controller.countBySeverity(ViolationSeverity.low)),
      ],
    );
  }

  Widget _alertCard(ViolationModel alert) {
    final config = _getSeverityConfig(alert.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config["bg"],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config["border"]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(config["icon"], size: 24, color: config["text"]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badgeRow(alert, config),
                    const SizedBox(height: 4),
                    Text(
                      alert.description,
                      style: TextStyle(color: config["text"], fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    _locationTimeRow(alert),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => controller.dismissAlert(alert.id),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),

          if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(alert.imageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    // 🟢 FIXED: CHANGED FROM ElevatedButton.styleFrom TO OutlinedButton.styleFrom
                    backgroundColor: AppColor.cardBg,
                    side: BorderSide(color: AppColor.borderColor),
                    foregroundColor: AppColor.textSecondary,
                  ),
                  icon: const Icon(LucideIcons.eye, size: 16),
                  label: const Text("View Details"),
                  onPressed: () => controller.viewDetails(alert),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.cardBg,
                    side: BorderSide(color: config["border"]),
                    foregroundColor: config["text"],
                    elevation: 0,
                  ),
                  onPressed: () => controller.acknowledgeAlert(alert.id),
                  child: const Text("Acknowledge"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeRow(ViolationModel alert, Map<String, dynamic> config) {
    return Row(
      children: [
        _badge(icon: _getTypeIcon(alert.type), text: alert.type.name, color: config["text"]),
        const SizedBox(width: 6), // 🟢 ADDED SPACING BETWEEN BADGES
        _badge(text: alert.severity.name.toUpperCase(), color: config["text"]),
      ],
    );
  }

  Widget _badge({required String text, IconData? icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: color),
          if (icon != null) const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _locationTimeRow(ViolationModel alert) {
    return Row(
      children: [
        Icon(LucideIcons.mapPin, size: 14, color: AppColor.textTertiary),
        const SizedBox(width: 4),
        Text(alert.zone, style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
        const SizedBox(width: 10),
        Icon(LucideIcons.clock, size: 14, color: AppColor.textTertiary),
        const SizedBox(width: 4),
        Text(DateFormat('hh:mm a').format(alert.time),
            style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
      ],
    );
  }

  Map<String, dynamic> _getSeverityConfig(ViolationSeverity severity) {
    late final Color base;
    late final IconData icon;
    switch (severity) {
      case ViolationSeverity.high:
        base = Colors.red;
        icon = LucideIcons.circleAlert;
        break;
      case ViolationSeverity.medium:
        base = Colors.amber;
        icon = LucideIcons.triangleAlert;
        break;
      case ViolationSeverity.low:
        base = Colors.blue;
        icon = LucideIcons.circleAlert;
        break;
    }
    return {
      "bg": AppColor.tintedSurface(base),
      "border": AppColor.accentBorder(base),
      "text": AppColor.accentText(base),
      "icon": icon,
    };
  }

  IconData _getTypeIcon(ViolationType type) {
    switch (type) {
      case ViolationType.PPE:
        return LucideIcons.hardHat;
      case ViolationType.Unauthorized:
        return LucideIcons.circleAlert;
      case ViolationType.Hazardous:
        return LucideIcons.triangleAlert;
      case ViolationType.Material:
        return LucideIcons.box;
    }
  }

  Widget _noAlertWidget() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 70),
          const SizedBox(height: 12),
          Text("No Active Alerts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary)),
          Text("All safety protocols are being followed",
              style: TextStyle(fontSize: 13, color: AppColor.textSecondary)),
        ],
      ),
    );
  }

  Widget _severityCard(String label, Color color, int count) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            Text(
              "$count",
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
