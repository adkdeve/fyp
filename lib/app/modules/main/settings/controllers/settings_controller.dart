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

import '../../../../core/config/app_config.dart';
import '../../../../data/models/settings_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../routes/app_pages.dart';

class SettingsController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final FirestoreService _firestore = FirestoreService.to;

  final notificationSettings = NotificationSettings(
    criticalAlerts: true,
    mediumAlerts: true,
    lowAlerts: true,
  ).obs;
  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final cameraCount = 0.obs;
  final avatarRefreshKey = 0.obs;

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
      final user = await _firestore.getMe();
      currentUser.value = UserModel.fromJson(user);
      avatarRefreshKey.value++;
      await _auth.saveUserData(user);
    } catch (_) {
      currentUser.value = await _auth.getUserData();
      avatarRefreshKey.value++;
    }
  }

  Future<void> loadNotificationSettings() async {
    try {
      final raw = await _firestore.getNotificationSettings();
      notificationSettings.value = NotificationSettings.fromJson(raw);
    } catch (_) {}
  }

  Future<void> loadCameraCount() async {
    try {
      final cameras = await _firestore.getCameras();
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
      lowAlerts: key == 'lowAlerts'
          ? !current.lowAlerts
          : current.lowAlerts,
    );
    notificationSettings.value = next;
    try {
      final updated = await _firestore.updateNotificationSettings(next.toJson());
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

  Future<void> navigateToProfile() async {
    await Get.to(ProfileView(), binding: ProfileBinding());
    await loadProfile();
  }

  void navigateToCameraManagement() =>
      Get.to(CameraManagementView(), binding: CameraManagementBinding());

  void navigateToHelp() =>
      Get.to(HelpSupportView(), binding: HelpsupportBinding());

  void navigateToTerms() =>
      Get.to(TermsPrivacyView(), binding: TermsprivacyBinding());

  String get userInitials {
    final name = currentUser.value?.name ?? '';
    final parts = name.split(' ').where((p) => p.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return 'U';
    return parts.map((p) => p[0]).join().toUpperCase();
  }

  String? get resolvedAvatarUrl {
    final raw = currentUser.value?.image?.trim() ?? '';
    if (raw.isEmpty) return null;

    String resolved;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      resolved = raw;
    } else if (raw.startsWith('/')) {
      resolved = '${AppConfig.imageBaseUrl}$raw';
    } else {
      resolved = '${AppConfig.imageBaseUrl}/$raw';
    }

    final separator = resolved.contains('?') ? '&' : '?';
    return '$resolved${separator}v=${avatarRefreshKey.value}';
  }
}
