import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../controllers/alerts_controller.dart';
import '../../../../data/models/violation_model.dart';

class AlertsView extends StatelessWidget {
  final AlertsController controller = Get.put(AlertsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Active Alerts"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Obx(() {
        final activeAlerts = controller.activeAlerts;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _summaryCards(activeAlerts),
              const SizedBox(height: 14),
              if (activeAlerts.isEmpty) _noAlertWidget(),
              if (activeAlerts.isNotEmpty)
                ...activeAlerts.map((alert) => _alertCard(alert)),
            ],
          ),
        );
      }),
    );
  }

  // 🔴🟡🔵 Summary Cards based on enum
  Widget _summaryCards(List<ViolationModel> activeAlerts) {
    return Row(
      children: [
        _severityCard(
          "High",
          Colors.red,
          activeAlerts.where((a) => a.severity == ViolationSeverity.high).length,
        ),
        _severityCard(
          "Medium",
          Colors.orange,
          activeAlerts.where((a) => a.severity == ViolationSeverity.medium).length,
        ),
        _severityCard(
          "Low",
          Colors.blue,
          activeAlerts.where((a) => a.severity == ViolationSeverity.low).length,
        ),
      ],
    );
  }

  // 🔔 Alert Card (Updated for enum model)
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
          // 🔹 Header Section with Icon + Dismiss
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
                      style: TextStyle(
                        color: config["text"],
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
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

          // 🔹 If image exists, show it
          if (alert.imageUrl != null && alert.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(alert.imageUrl!, height: 160, fit: BoxFit.cover),
            ),
          ],

          const SizedBox(height: 10),

          // 🎯 Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.eye, size: 16),
                  label: const Text("View Details"),
                  onPressed: () => controller.viewDetails(alert),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: config["border"]),
                    foregroundColor: config["text"],
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

  // 🏷 Badge Row (Type + Severity)
  Widget _badgeRow(ViolationModel alert, Map<String, dynamic> config) {
    return Wrap(
      spacing: 6,
      children: [
        _badge(
          icon: _getTypeIcon(alert.type),
          text: alert.type.name,
          color: config["text"],
        ),
        _badge(
          text: alert.severity.name.toUpperCase(),
          color: config["text"],
        ),
      ],
    );
  }

  Widget _badge({required String text, IconData? icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 14, color: color),
          if (icon != null) const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  // 📌 Location + Time
  Widget _locationTimeRow(ViolationModel alert) {
    return Row(
      children: [
        const Icon(LucideIcons.mapPin, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(alert.zone, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 10),
        const Icon(LucideIcons.clock, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(DateFormat('hh:mm a').format(alert.time),
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // 🎨 Enum-Based Severity Config
  Map<String, dynamic> _getSeverityConfig(ViolationSeverity severity) {
    switch (severity) {
      case ViolationSeverity.high:
        return {
          "bg": Colors.red.shade50,
          "border": Colors.red.shade200,
          "text": Colors.red.shade700,
          "icon": LucideIcons.circleAlert,
        };
      case ViolationSeverity.medium:
        return {
          "bg": Colors.yellow.shade50,
          "border": Colors.yellow.shade200,
          "text": Colors.yellow.shade700,
          "icon": LucideIcons.triangleAlert,
        };
      case ViolationSeverity.low:
      return {
          "bg": Colors.blue.shade50,
          "border": Colors.blue.shade200,
          "text": Colors.blue.shade700,
          "icon": LucideIcons.circleAlert,
        };
    }
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

  // 🟢 No Alerts
  Widget _noAlertWidget() {
    return Center(
      child: Column(
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 70),
          SizedBox(height: 12),
          Text("No Active Alerts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("All safety protocols are being followed",
              style: TextStyle(fontSize: 13, color: Colors.grey)),
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
            Text("$count",
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
