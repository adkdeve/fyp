import 'dart:ui';

class AnalyticsData {
  final String period;
  final int violations;

  AnalyticsData({required this.period, required this.violations});
}

class ViolationTypeData {
  final String name;
  final int value;
  final Color color;

  ViolationTypeData({required this.name, required this.value, required this.color});
}

class ComplianceTrend {
  final String week;
  final int compliance;

  ComplianceTrend({required this.week, required this.compliance});
}

class ZonePerformance {
  final String zone;
  final int compliance;
  final int violations;
  final String id;

  ZonePerformance({
    required this.zone,
    required this.compliance,
    required this.violations,
    required this.id,
  });
}