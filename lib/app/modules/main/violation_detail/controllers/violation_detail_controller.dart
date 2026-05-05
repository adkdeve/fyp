import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/firestore_service.dart';
import '../../alerts/controllers/alerts_controller.dart';
import '../../controllers/main_controller.dart';
import '../../history/controllers/history_controller.dart';

class ViolationDetailController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final MainController _main = Get.find<MainController>();

  final Rx<ViolationModel?> selectedViolation = Rx<ViolationModel?>(null);
  final isResolving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final violation = Get.arguments as ViolationModel?;
    if (violation != null) {
      selectedViolation.value = violation;
      _main.setSelectedViolation(violation);
    } else {
      Get.back();
    }
  }

  Future<void> handleResolve() async {
    final v = selectedViolation.value;
    if (v == null) return;
    isResolving.value = true;
    try {
      final id = int.tryParse(v.id);
      if (id != null) {
        await _firestore.resolveViolation(id.toString(), status: 'resolved');
      final updated = v.copyWith(status: ViolationStatus.resolved);
      selectedViolation.value = updated;
      _main.upsertViolation(updated);
      if (Get.isRegistered<AlertsController>()) {
        Get.find<AlertsController>().applyViolationUpdate(updated);
      }
      if (Get.isRegistered<HistoryController>()) {
        Get.find<HistoryController>().applyViolationUpdate(updated);
      }
      Get.snackbar(
        'Resolved',
        'Violation marked as resolved',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isResolving.value = false;
    }
  }

  Future<void> handleMarkFalsePositive() async {
    final v = selectedViolation.value;
    if (v == null) return;
    isResolving.value = true;
    try {
      final id = int.tryParse(v.id);
      if (id != null) {
        await _firestore.resolveViolation(id.toString(), status: 'false_positive');
      final updated = v.copyWith(status: ViolationStatus.dismissed);
      selectedViolation.value = updated;
      _main.upsertViolation(updated);
      if (Get.isRegistered<AlertsController>()) {
        Get.find<AlertsController>().applyViolationUpdate(updated);
      }
      if (Get.isRegistered<HistoryController>()) {
        Get.find<HistoryController>().applyViolationUpdate(updated);
      }
      Get.snackbar(
        'Updated',
        'Marked as false positive',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isResolving.value = false;
    }
  }

  Future<void> handleDownload() async {
    final v = selectedViolation.value;
    if (v == null) return;
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}violation_${v.id}_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    await file.writeAsString('''
Violation Report
ID: ${v.id}
Type: ${v.rawType ?? v.type.name}
Severity: ${v.severity.name}
Status: ${v.status.name}
Location: ${v.zone}
Detected: ${v.time.toIso8601String()}
Description: ${v.description}
Confidence: ${v.confidence ?? 0}
Snapshot: ${v.imageUrl ?? ''}
''');
    Get.snackbar(
      'Report Saved',
      file.path,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void handleShare() {
    final v = selectedViolation.value;
    if (v == null) return;
    Get.dialog(
      AlertDialog(
        title: const Text('Share Violation'),
        content: Text('Violation #${v.id}\n${v.description}\n${v.zone}'),
        actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
      ),
    );
  }

  Map<String, dynamic> getSeverityConfig(ViolationSeverity severity) {
    switch (severity) {
      case ViolationSeverity.high:
        return {
          'bg': Colors.red[50]!,
          'border': Colors.red,
          'text': Colors.red[700]!,
          'badge': Colors.red[100]!,
        };
      case ViolationSeverity.medium:
        return {
          'bg': Colors.yellow[50]!,
          'border': Colors.orange,
          'text': Colors.orange[700]!,
          'badge': Colors.orange[100]!,
        };
      case ViolationSeverity.low:
        return {
          'bg': Colors.blue[50]!,
          'border': Colors.blue,
          'text': Colors.blue[700]!,
          'badge': Colors.blue[100]!,
        };
    }
  }

  List<String> getRecommendedActions(ViolationType type) {
    switch (type) {
      case ViolationType.PPE:
        return [
          'Ensure worker is equipped with proper safety gear',
          'Conduct immediate safety briefing',
          'Document incident in safety log',
        ];
      case ViolationType.Unauthorized:
        return [
          'Escort unauthorized personnel from restricted area',
          'Review access control procedures',
          'Reinforce signage and barriers',
        ];
      case ViolationType.Hazardous:
        return [
          'Immediately move workers to safe distance',
          'Secure hazardous area perimeter',
          'Conduct safety assessment',
        ];
      case ViolationType.Material:
        return [
          'Relocate materials to designated storage',
          'Clear walkways and work areas',
          'Brief team on proper material handling',
        ];
    }
  }
}
