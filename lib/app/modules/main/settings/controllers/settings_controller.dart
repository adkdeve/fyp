import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/settings_model.dart';

class SettingsController extends GetxController {
  final notificationSettings = NotificationSettings(
    criticalAlerts: true,
    mediumAlerts: true,
    dailySummary: false,
  ).obs;

  final autoDetection = true.obs;

  void toggleNotification(String key) {
    final current = notificationSettings.value;
    notificationSettings.value = current.copyWith(
      criticalAlerts: key == 'criticalAlerts' ? !current.criticalAlerts : current.criticalAlerts,
      mediumAlerts: key == 'mediumAlerts' ? !current.mediumAlerts : current.mediumAlerts,
      dailySummary: key == 'dailySummary' ? !current.dailySummary : current.dailySummary,
    );
  }

  void toggleAutoDetection() {
    autoDetection.value = !autoDetection.value;
  }

  void handleLogout() {
    Get.dialog(
      AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Logging out...',
                'You will be redirected to the login screen.',
                snackPosition: SnackPosition.BOTTOM,
              );
              // TODO: Implement actual logout logic
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void navigateToProfile() {
    Get.toNamed('/profile');
  }

  void navigateToCameraManagement() {
    Get.toNamed('/camera-management');
  }

  void navigateToHelp() {
    Get.toNamed('/help');
  }

  void navigateToTerms() {
    Get.toNamed('/terms');
  }
}