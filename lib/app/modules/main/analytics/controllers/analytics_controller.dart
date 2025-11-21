import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/analytics_model.dart';

class AnalyticsController extends GetxController {
  final RxString timeRange = 'week'.obs;

  final weeklyData = [
    AnalyticsData(period: "Mon", violations: 12),
    AnalyticsData(period: "Tue", violations: 8),
    AnalyticsData(period: "Wed", violations: 15),
    AnalyticsData(period: "Thu", violations: 6),
    AnalyticsData(period: "Fri", violations: 9),
    AnalyticsData(period: "Sat", violations: 4),
    AnalyticsData(period: "Sun", violations: 2),
  ];

  final monthlyData = [
    AnalyticsData(period: "Week 1", violations: 45),
    AnalyticsData(period: "Week 2", violations: 38),
    AnalyticsData(period: "Week 3", violations: 52),
    AnalyticsData(period: "Week 4", violations: 30),
  ];

  final violationTypeData = [
    ViolationTypeData(name: "PPE", value: 45, color: Color(0xFF3b82f6)),
    ViolationTypeData(name: "Unauthorized", value: 25, color: Color(0xFFf59e0b)),
    ViolationTypeData(name: "Hazardous", value: 20, color: Color(0xFFef4444)),
    ViolationTypeData(name: "Material", value: 10, color: Color(0xFF8b5cf6)),
  ];

  final complianceTrend = [
    ComplianceTrend(week: "W1", compliance: 82),
    ComplianceTrend(week: "W2", compliance: 85),
    ComplianceTrend(week: "W3", compliance: 87),
    ComplianceTrend(week: "W4", compliance: 89),
  ];

  final zonePerformance = [
    ZonePerformance(zone: "Zone A - Main Entrance", compliance: 95, violations: 3, id: "A"),
    ZonePerformance(zone: "Zone B - Construction Area", compliance: 82, violations: 12, id: "B"),
    ZonePerformance(zone: "Zone C - Storage Area", compliance: 91, violations: 5, id: "C"),
    ZonePerformance(zone: "Zone D - Scaffolding", compliance: 88, violations: 8, id: "D"),
  ];

  // Key Metrics
  final activeViolations = 8;
  final totalViolations = 56;
  final complianceRate = 89;
  final avgResponseTime = 2.3;

  void setTimeRange(String range) {
    timeRange.value = range;
    Get.snackbar(
      'Filter Applied',
      'Filtering analytics for: ${range == "week" ? "This Week" : range == "month" ? "This Month" : "This Year"}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void handleExport() {
    Get.snackbar(
      'Exporting Analytics Report',
      'Format: PDF\nIncluding:\n• Violation trends\n• Compliance metrics\n• Zone performance\n• AI detection statistics',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 3),
    );
  }

  void showMetricDetails(String metric) {
    String message = '';
    switch (metric) {
      case 'compliance':
        message = 'Compliance Rate: $complianceRate%\n\n✓ Safe workers: 25/28\n✓ PPE compliance: 92%\n✓ Zone compliance: 88%';
        break;
      case 'violations':
        message = 'Total Violations: $totalViolations\n\n• Active: $activeViolations\n• Resolved: ${totalViolations - activeViolations}\n• This week: -12% vs last week';
        break;
      case 'response':
        message = 'Average Response Time: ${avgResponseTime}s\n\nFrom detection to alert delivery:\n• Fastest: 1.8s\n• Average: 2.3s\n• Slowest: 3.1s';
        break;
      case 'zones':
        message = 'Active Monitoring Zones: 4/4\n\n✓ Zone A - Main Entrance\n✓ Zone B - Construction Area\n✓ Zone C - Storage Area\n✓ Zone D - Scaffolding';
        break;
    }
    Get.dialog(
      AlertDialog(
        title: Text('Metric Details'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void showViolationTypeDetails(ViolationTypeData data) {
    final total = totalViolations * (data.value / 100);
    Get.dialog(
      AlertDialog(
        title: Text('${data.name} Violations'),
        content: Text(
            'Percentage: ${data.value}%\n'
                'Total incidents: ${total.round()}\n'
                'Trend: ${data.value > 30 ? "High" : data.value > 15 ? "Medium" : "Low"} priority'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void showZoneDetails(ZonePerformance zone) {
    Get.dialog(
      AlertDialog(
        title: Text(zone.zone),
        content: Text(
            'Compliance: ${zone.compliance}%\n'
                'Violations this week: ${zone.violations}\n'
                'Status: ${zone.compliance >= 90 ? "Excellent" : zone.compliance >= 80 ? "Good" : "Needs Improvement"}\n\n'
                'Most common violation: ${zone.id == "B" ? "Missing hard hat" : zone.id == "D" ? "Unauthorized access" : "PPE compliance"}'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  List<AnalyticsData> get currentData {
    return timeRange.value == 'month' ? monthlyData : weeklyData;
  }
}