import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/violation_model.dart';

class ViolationDetailController extends GetxController {
  final Rx<ViolationModel?> selectedViolation = Rx<ViolationModel?>(null);

  @override
  void onInit() {
    super.onInit();
    print('🎯 ViolationDetailController initialized');
    print('📦 Get.arguments: ${Get.arguments}');
    print('📦 Get.arguments type: ${Get.arguments?.runtimeType}');

    // Get violation from arguments
    final violation = Get.arguments as ViolationModel?;
    print('🔍 Violation received: $violation');

    if (violation != null) {
      selectedViolation.value = violation;
      print('✅ Violation set successfully: ${violation.id}');
    } else {
      print('❌ No violation found, navigating back');
      Get.back(); // Navigate back if no violation provided
    }
  }


  void handleResolve() {
    if (selectedViolation.value != null) {
      // Update the violation status to resolved
      final updatedViolation = selectedViolation.value!.copyWith(
        status: ViolationStatus.resolved,
      );
      selectedViolation.value = updatedViolation;

      // TODO: Update in your main violations list
      Get.snackbar(
        'Violation Resolved',
        'Violation has been marked as resolved',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void handleDownload() {
    Get.snackbar(
      'Downloading Report',
      'Violation report with evidence is being downloaded...',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void handleShare() {
    Get.snackbar(
      'Sharing Details',
      'Violation details are being shared via email...',
      snackPosition: SnackPosition.BOTTOM,
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