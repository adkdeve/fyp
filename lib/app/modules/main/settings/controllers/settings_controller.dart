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
import '../../../../data/models/user_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/safety_api_service.dart';
import '../../../../routes/app_pages.dart';

class SettingsController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final SafetyApiService _api = SafetyApiService.to;

  final notificationSettings = NotificationSettings(
    criticalAlerts: true,
    mediumAlerts: true,
  ).obs;
  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final cameraCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettingsData();
  }

  Future<void> loadSettingsData() async {
    await Future.wait([
      loadProfile(),
      loadNotificationSettings(),
      loadCameraCount(),
    ]);
  }

  Future<void> loadProfile() async {
    try {
      final user = await _api.getMe();
      currentUser.value = UserModel.fromJson(user);
      await _auth.saveUserData(user);
    } catch (_) {
      currentUser.value = await _auth.getUserData();
    }
  }

  Future<void> loadNotificationSettings() async {
    try {
      final raw = await _api.getNotificationSettings();
      notificationSettings.value = NotificationSettings.fromJson(raw);
    } catch (_) {}
  }

  Future<void> loadCameraCount() async {
    try {
      final cameras = await _api.getCameras(enabled: true);
      cameraCount.value = cameras.length;
    } catch (_) {}
  }

  Future<void> toggleNotification(String key) async {
    final current = notificationSettings.value;
    final next = current.copyWith(
      criticalAlerts: key == 'criticalAlerts'
          ? !current.criticalAlerts
          : current.criticalAlerts,
      mediumAlerts: key == 'mediumAlerts'
          ? !current.mediumAlerts
          : current.mediumAlerts,
    );
    notificationSettings.value = next;
    try {
      final updated = await _api.updateNotificationSettings(next.toJson());
      notificationSettings.value = NotificationSettings.fromJson(updated);
    } catch (e) {
      notificationSettings.value = current;
      Get.snackbar(
        'Settings Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void handleLogout() {
    Get.dialog(
      AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await _auth.logout();
              Get.offAllNamed(Routes.LOGIN);
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void navigateToProfile() => Get.to(ProfileView(), binding: ProfileBinding());

  void navigateToCameraManagement() =>
      Get.to(CameraManagementView(), binding: CameraManagementBinding());

  void navigateToHelp() =>
      Get.to(HelpSupportView(), binding: HelpsupportBinding());

  void navigateToTerms() =>
      Get.to(TermsPrivacyView(), binding: TermsprivacyBinding());
}
