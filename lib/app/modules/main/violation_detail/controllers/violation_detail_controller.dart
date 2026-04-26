import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/safety_api_service.dart';

class ViolationDetailController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;

  final Rx<ViolationModel?> selectedViolation = Rx<ViolationModel?>(null);
  final isResolving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final violation = Get.arguments as ViolationModel?;
    if (violation != null) {
      selectedViolation.value = violation;
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
        await _api.resolveViolation(id, 'resolved');
      }
      selectedViolation.value = v.copyWith(status: ViolationStatus.resolved);
      Get.snackbar('Resolved', 'Violation marked as resolved',
          snackPosition: SnackPosition.BOTTOM);
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
        await _api.resolveViolation(id, 'false_positive');
      }
      selectedViolation.value = v.copyWith(status: ViolationStatus.dismissed);
      Get.snackbar('Updated', 'Marked as false positive',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isResolving.value = false;
    }
  }

  void handleDownload() {
    Get.snackbar('Downloading', 'Violation report being downloaded...',
        snackPosition: SnackPosition.BOTTOM);
  }

  void handleShare() {
    Get.snackbar('Sharing', 'Violation details being shared...',
        snackPosition: SnackPosition.BOTTOM);
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
