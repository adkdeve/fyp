import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:construction_safety/utils/helpers/snackbar.dart';

import '../../../../data/models/violation_model.dart';
import '../../controllers/main_controller.dart';

/// Analytics ab web ke AnalyticsPage jaisa hai — sab kuch client-side compute
/// hota hai MainController ke real-time `violations` + `cameras` se (web ke
/// SiteDataContext ke barabar). Koi backend analytics endpoint use nahi hota.
class AnalyticsController extends GetxController {
  final MainController _main = Get.find<MainController>();

  /// 'week' | 'month' | 'year'
  final RxString timeRange = 'week'.obs;

  void setTimeRange(String range) => timeRange.value = range;

  // ── Date range filter ───────────────────────────────────────────────────────
  bool _inRange(DateTime d) {
    final now = DateTime.now();
    switch (timeRange.value) {
      case 'month':
        return d.isAfter(now.subtract(const Duration(days: 30)));
      case 'year':
        return d.isAfter(now.subtract(const Duration(days: 365)));
      default:
        return d.isAfter(now.subtract(const Duration(days: 7)));
    }
  }

  /// Selected range ke andar ki violations (latest order me).
  List<ViolationModel> get filtered =>
      _main.violations.where((v) => _inRange(v.time)).toList();

  // ── Key metrics ─────────────────────────────────────────────────────────────
  int get totalViolations => filtered.length;
  int get highCount => filtered.where((v) => v.severity == ViolationSeverity.high).length;
  int get mediumCount => filtered.where((v) => v.severity == ViolationSeverity.medium).length;
  int get lowCount => filtered.where((v) => v.severity == ViolationSeverity.low).length;

  /// "Resolved" = open (active) ke alawa koi bhi status.
  int get resolvedCount => filtered.where((v) => v.status != ViolationStatus.active).length;

  int get activeCameras => _main.cameras.where((c) => c.enabled).length;

  int get compliancePct {
    if (totalViolations == 0) return 100;
    final pct = 100 - ((highCount / totalViolations) * 100).round();
    return pct < 0 ? 0 : pct;
  }

  // ── Violations over time (bar chart) ────────────────────────────────────────
  List<TimePoint> get timeSeries {
    final list = filtered.toList()..sort((a, b) => a.time.compareTo(b.time));
    final buckets = <String, int>{};
    for (final v in list) {
      final key = _bucketLabel(v.time);
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    return buckets.entries.map((e) => TimePoint(e.key, e.value)).toList();
  }

  String _bucketLabel(DateTime d) {
    switch (timeRange.value) {
      case 'month':
        return DateFormat('MMM d').format(d);
      case 'year':
        return DateFormat('MMM').format(d);
      default:
        return DateFormat('EEE').format(d); // Mon, Tue, ...
    }
  }

  // ── Violation type breakdown (top 6) ────────────────────────────────────────
  List<TypeCount> get typeBreakdown {
    final counts = <String, int>{};
    for (final v in filtered) {
      final key = v.rawType ?? v.type.name;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(6)
        .map((e) => TypeCount(_labelForType(e.key), e.value, _colorForType(e.key)))
        .toList();
  }

  // ── Cameras by violations (top 5) ───────────────────────────────────────────
  // Firebase camera ids string hain aur violation.cameraId int parse hota hai,
  // isliye reliable grouping ke liye zone (camera name/location) use kar rahe hain.
  List<CameraCount> get topCameras {
    final counts = <String, int>{};
    for (final v in filtered) {
      final key = v.zone.trim().isNotEmpty ? v.zone : 'Unknown';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => CameraCount(e.key, e.value)).toList();
  }

  // ── Export CSV (client-side, web jaisa) ─────────────────────────────────────
  Future<void> handleExport() async {
    try {
      final rows = filtered.map((v) {
        return [
          v.id,
          v.rawType ?? v.type.name,
          v.severity.name,
          v.status.name,
          v.confidence?.toString() ?? '',
          v.cameraId?.toString() ?? '',
          _csvEscape(v.zone),
          v.time.toIso8601String(),
        ].join(',');
      }).toList();

      final csv = [
        'ID,Type,Severity,Status,Confidence,CameraID,CameraName,DetectedAt',
        ...rows,
      ].join('\r\n');

      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}violations_${timeRange.value}_$date.csv',
      );
      await file.writeAsString('﻿$csv'); // BOM for Excel
      SnackBarUtils.showSnackBar(file.path, title: 'Export Ready');
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Export Failed');
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── Type label + color (web VIOLATION_COLORS ke barabar) ────────────────────
  String _labelForType(String raw) {
    final words = raw.split('_').where((w) => w.isNotEmpty).map((w) {
      return w[0].toUpperCase() + w.substring(1);
    });
    return words.join(' ');
  }

  Color _colorForType(String raw) {
    switch (raw) {
      case 'no_helmet':
        return const Color(0xFFEF4444);
      case 'no_vest':
        return const Color(0xFFF59E0B);
      case 'no_mask':
        return const Color(0xFF3B82F6);
      case 'no_gloves':
        return const Color(0xFF8B5CF6);
      case 'no_boots':
        return const Color(0xFF06B6D4);
      case 'unauthorized_zone':
        return const Color(0xFFEC4899);
      case 'unsafe_material':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF6366F1);
    }
  }
}

// ── Lightweight view models ────────────────────────────────────────────────────
class TimePoint {
  final String label;
  final int count;
  TimePoint(this.label, this.count);
}

class TypeCount {
  final String label;
  final int count;
  final Color color;
  TypeCount(this.label, this.count, this.color);
}

class CameraCount {
  final String name;
  final int count;
  CameraCount(this.name, this.count);
}
