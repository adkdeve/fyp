import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/analytics_model.dart';
import '../../../../data/services/safety_api_service.dart';

class AnalyticsController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;

  final RxString timeRange = 'week'.obs;
  final isLoading = false.obs;

  // ── Reactive data (populated from API) ────────────────────────────────────
  final weeklyData = <AnalyticsData>[].obs;
  final monthlyData = <AnalyticsData>[].obs;
  final violationTypeData = <ViolationTypeData>[].obs;
  final complianceTrend = <ComplianceTrend>[].obs;
  final zonePerformance = <ZonePerformance>[].obs;

  // Key metrics
  final activeViolations = 0.obs;
  final totalViolations = 0.obs;
  final complianceRate = 0.obs;
  final avgResponseTime = 0.0.obs;
  final activeZones = 0.obs;
  final detectionAccuracy = 94.obs;
  final falsePositiveRate = 0.0.obs;
  final processingFps = 30.obs;

  static const _typeColors = {
    'PPE': Color(0xFF3b82f6),
    'Unauthorized': Color(0xFFf59e0b),
    'Hazardous': Color(0xFFef4444),
    'Material': Color(0xFF8b5cf6),
    'Other': Color(0xFF6b7280),
  };

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  Future<void> fetchAll({int days = 7}) async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchSummary(days: days),
        fetchTrend(days: days),
        fetchByType(days: days),
        fetchByCamera(days: days),
      ]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchSummary({int days = 7}) async {
    try {
      final s = await _api.getSummary(days: days);
      totalViolations.value = (s['total_violations'] as int?) ?? 0;
      activeViolations.value = (s['open_violations'] as int?) ?? 0;
      complianceRate.value = (s['compliance_rate'] as int?) ?? 100;
      avgResponseTime.value =
          (s['avg_response_time'] as num?)?.toDouble() ?? 0.0;
      activeZones.value = (s['active_zones'] as int?) ?? 0;
      detectionAccuracy.value = (s['detection_accuracy'] as int?) ?? 94;
      falsePositiveRate.value =
          (s['false_positive_rate'] as num?)?.toDouble() ?? 0.0;
      processingFps.value = (s['processing_fps'] as int?) ?? 30;
    } catch (_) {}
  }

  Future<void> fetchTrend({int days = 7}) async {
    try {
      final raw = await _api.getTrend(days: days);
      final parsed = raw.map((e) {
        final m = e as Map<String, dynamic>;
        return AnalyticsData(
          period: m['date'] as String? ?? '',
          violations: (m['count'] as int?) ?? 0,
        );
      }).toList();
      if (days <= 7) {
        weeklyData.assignAll(parsed);
      } else {
        monthlyData.assignAll(parsed);
      }
      complianceTrend.assignAll(
        parsed
            .map((e) => ComplianceTrend(week: e.period, compliance: e.violations))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> fetchByType({int days = 7}) async {
    try {
      final raw = await _api.getByType(days: days);
      final parsed = raw.map((e) {
        final m = e as Map<String, dynamic>;
        final name = _friendlyTypeName(m['type'] as String? ?? 'Other');
        return ViolationTypeData(
          name: name,
          value: (m['count'] as int?) ?? 0,
          color: _typeColors[name] ?? const Color(0xFF6b7280),
        );
      }).toList();
      violationTypeData.assignAll(parsed);
    } catch (_) {}
  }

  Future<void> fetchByCamera({int days = 7}) async {
    try {
      final raw = await _api.getByCamera(days: days);
      var totalCount = 0;
      for (final item in raw) {
        final m = item as Map<String, dynamic>;
        totalCount += (m['count'] as int?) ?? 0;
      }
      final parsed = raw.asMap().entries.map((entry) {
        final m = entry.value as Map<String, dynamic>;
        final count = (m['count'] as int?) ?? 0;
        final name =
            (m['camera_name'] ?? m['camera']) as String? ??
            'Camera ${entry.key + 1}';
        final share = totalCount == 0 ? 0 : ((count / totalCount) * 100).round();
        return ZonePerformance(
          zone: name,
          compliance: share,
          violations: count,
          id: (entry.key + 1).toString(),
        );
      }).toList();
      zonePerformance.assignAll(parsed);
    } catch (_) {}
  }

  // ── Type name mapping ──────────────────────────────────────────────────────
  String _friendlyTypeName(String raw) {
    switch (raw) {
      case 'no_helmet':
      case 'no_vest':
      case 'no_gloves':
      case 'no_boots':
      case 'no_mask':
        return 'PPE';
      case 'unauthorized_zone':
        return 'Unauthorized';
      case 'unsafe_material':
        return 'Material';
      default:
        return 'Hazardous';
    }
  }

  // ── UI actions ─────────────────────────────────────────────────────────────
  void setTimeRange(String range) {
    timeRange.value = range;
    final days = range == 'month'
        ? 30
        : range == 'year'
        ? 365
        : 7;
    fetchAll(days: days);
  }

  List<AnalyticsData> get currentData =>
      timeRange.value == 'month' ? monthlyData : weeklyData;

  Future<void> handleExport() async {
    try {
      final days = timeRange.value == 'month'
          ? 30
          : timeRange.value == 'year'
          ? 365
          : 7;
      final bytes = await _api.exportAnalytics(days: days);
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}analytics_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsBytes(bytes);
      Get.snackbar(
        'Export Ready',
        'Saved to ${file.path}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void showMetricDetails(String metric) {
    String message;
    switch (metric) {
      case 'compliance':
        message = 'Compliance Rate: ${complianceRate.value}%';
        break;
      case 'violations':
        message =
            'Total: ${totalViolations.value} • Active: ${activeViolations.value}';
        break;
      case 'response':
        message =
            'Avg response time: ${avgResponseTime.value.toStringAsFixed(1)}s';
        break;
      default:
        message = 'Monitoring ${activeZones.value} enabled camera zones';
    }
    Get.dialog(
      AlertDialog(
        title: Text('Metric Details'),
        content: Text(message),
        actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
      ),
    );
  }

  void showViolationTypeDetails(ViolationTypeData data) {
    Get.dialog(
      AlertDialog(
        title: Text('${data.name} Violations'),
        content: Text('Count: ${data.value}'),
        actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
      ),
    );
  }

  void showZoneDetails(ZonePerformance zone) {
    Get.dialog(
      AlertDialog(
        title: Text(zone.zone),
        content: Text(
          'Share of violations: ${zone.compliance}%\nViolations: ${zone.violations}',
        ),
        actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
      ),
    );
  }
}
