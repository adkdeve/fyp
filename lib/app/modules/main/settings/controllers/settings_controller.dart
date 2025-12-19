import 'package:construction_safety/app/modules/main/camera_management/bindings/camera_management_binding.dart';
import 'package:construction_safety/app/modules/main/camera_management/views/camera_management_view.dart';
import 'package:construction_safety/app/modules/main/helpsupport/bindings/helpsupport_binding.dart';
import 'package:construction_safety/app/modules/main/helpsupport/views/helpsupport_view.dart';
import 'package:construction_safety/app/modules/main/profile/bindings/profile_binding.dart';
import 'package:construction_safety/app/modules/main/profile/views/profile_view.dart';
import 'package:construction_safety/app/modules/main/termsprivacy/bindings/termsprivacy_binding.dart';
import 'package:construction_safety/app/modules/main/termsprivacy/views/termsprivacy_view.dart';
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
    Get.to(
      ProfileView(),
      binding: ProfileBinding()
    );
  }

  void navigateToCameraManagement() {
    Get.to(
        CameraManagementView(),
      binding: CameraManagementBinding()
    );
  }

  void navigateToHelp() {
    Get.to(
        HelpSupportView(),
        binding: HelpsupportBinding()
    );
  }

  void navigateToTerms() {
    Get.to(
        TermsPrivacyView(),
        binding: TermsprivacyBinding()
    );
  }
}