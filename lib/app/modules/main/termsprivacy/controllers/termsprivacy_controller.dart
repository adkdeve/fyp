import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TermsPrivacyController extends GetxController {
  // Reactive variable for active tab
  var activeTab = 'terms'.obs;

  // Method to switch tabs
  void switchTab(String tab) {
    activeTab.value = tab;
  }

  // Method to handle accept button
  void handleAccept() {
    final tabName = activeTab.value == 'terms' ? 'Terms of Service' : 'Privacy Policy';
    Get.dialog(
      AlertDialog(
        title: const Text('Acknowledgement'),
        content: Text('You have acknowledged the $tabName.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}