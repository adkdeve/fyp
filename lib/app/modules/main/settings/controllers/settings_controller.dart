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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:construction_safety/utils/helpers/snackbar.dart';

import '../../../../core/config/app_config.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/services/ai_controls_service.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../../../data/services/notification_prefs.dart';
import '../../../../routes/app_pages.dart';

class SettingsController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final FirestoreService _firestore = FirestoreService.to;
  final AiControlsService _ai = AiControlsService();

  // Local preference storage key (dark mode; notification prefs NotificationPrefs mein)
  static const String _darkModeKey = 'dark_mode';

  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final cameraCount = 0.obs;
  final avatarRefreshKey = 0.obs;

  // ── Notifications (web-style, local) ───────────────────────────────────────
  final alertPopups = true.obs; // in-app violation pop-ups
  final soundAlerts = false.obs; // sound on alert
  final pushNotifications = true.obs; // device push notifications

  // ── Display ────────────────────────────────────────────────────────────────
  final isDarkMode = false.obs;

  // ── AI Detection Controls ──────────────────────────────────────────────────
  final ppeEnabled = false.obs;
  final fireEnabled = false.obs;
  final ppeLoading = false.obs;
  final fireLoading = false.obs;
  final mlOnline = false.obs;
  final mlChecked = false.obs; // status check complete hua ya nahi

  @override
  void onInit() {
    super.onInit();
    loadSettingsData();
  }

  Future<void> loadSettingsData() async {
    await Future.wait([
      loadProfile(),
      loadLocalPrefs(),
      loadCameraCount(),
      loadAiControls(),
    ]);
  }

  Future<void> loadProfile() async {
    try {
      // NOTE: getMe() FirebaseAuth + 'users' collection use karta hai, jo is app mein
      // istemal nahi hota (login custom 'officers' collection se hota hai). Wo khali/error
      // data return kar ke login ka sahi cache overwrite kar deta tha — isliye yahan
      // officers-based refresh use kar rahe hain.
      final fresh = await _auth.refreshUserData(); // officers/{id} se fresh data, cache update
      currentUser.value = fresh != null ? UserModel.fromJson(fresh) : await _auth.getUserData();
      avatarRefreshKey.value++;
    } catch (_) {
      currentUser.value = await _auth.getUserData();
      avatarRefreshKey.value++;
    }
  }

  Future<void> loadCameraCount() async {
    try {
      final user = await _auth.getUserData();
      final cameraIds = await _firestore.getCameraIdsBySiteIds(user?.siteIds);
      cameraCount.value = cameraIds.length;
    } catch (_) {
      cameraCount.value = 0;
    }
  }

  // ── Notification + display prefs ───────────────────────────────────────────
  Future<void> loadLocalPrefs() async {
    try {
      await NotificationPrefs.to.load();
      alertPopups.value = NotificationPrefs.to.alertPopups;
      soundAlerts.value = NotificationPrefs.to.soundAlerts;
      pushNotifications.value = NotificationPrefs.to.pushNotifications;

      final sp = await SharedPreferences.getInstance();
      isDarkMode.value = sp.getBool(_darkModeKey) ?? false;
    } catch (_) {}
  }

  void toggleAlertPopups(bool value) {
    alertPopups.value = value;
    NotificationPrefs.to.alertPopups = value;
    NotificationPrefs.to.save();
    SnackBarUtils.showSnackBar(
      value
          ? 'You will see in-app pop-ups for new violations.'
          : 'In-app violation pop-ups have been turned off.',
      title: value ? 'Alert pop-ups enabled' : 'Alert pop-ups disabled',
    );
  }

  void toggleSoundAlerts(bool value) {
    soundAlerts.value = value;
    NotificationPrefs.to.soundAlerts = value;
    NotificationPrefs.to.save();
    SnackBarUtils.showSnackBar(
      value
          ? 'A sound will play for new violation alerts.'
          : 'Sound for violation alerts has been turned off.',
      title: value ? 'Sound alerts enabled' : 'Sound alerts disabled',
    );
  }

  void togglePushNotifications(bool value) {
    pushNotifications.value = value;
    NotificationPrefs.to.pushNotifications = value;
    NotificationPrefs.to.save();
    SnackBarUtils.showSnackBar(
      value
          ? 'Device notifications will appear for new violations.'
          : 'Device notifications have been turned off.',
      title: value ? 'Push notifications enabled' : 'Push notifications disabled',
    );
  }

  Future<void> toggleDarkMode(bool value) async {
    isDarkMode.value = value;
    final mode = value ? ThemeMode.dark : ThemeMode.light;
    AppConfig.appDefaultTheme = mode;
    Get.changeThemeMode(mode);

    // AppColor.* (backgrounds/cards/text/status bar) Theme.of par depend nahi karte,
    // isliye poora tree forcibly rebuild karte hain — warna screen refresh maangta hai.
    Get.forceAppUpdate();

    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_darkModeKey, value);
  }

  // ── AI Detection Controls ──────────────────────────────────────────────────
  Future<void> loadAiControls() async {
    // Pehle local prefs se UI seed karo
    final saved = await _ai.loadPrefs();
    ppeEnabled.value = saved.ppe;
    fireEnabled.value = saved.fire;

    // Backend status check karo
    final status = await _ai.getStatus();
    mlChecked.value = true;
    if (status == null) {
      mlOnline.value = false;
      return;
    }

    mlOnline.value = true;
    // Backend ke authoritative state se UI sync karo
    ppeEnabled.value = status['helmet'] ?? saved.ppe;
    fireEnabled.value = status['firesmoke'] ?? saved.fire;

    // Saved prefs ko backend par dobara apply karo (camera workers ke liye)
    await _ai.applyPrefs(DetectionPrefs(ppe: ppeEnabled.value, fire: fireEnabled.value));
  }

  Future<void> togglePpe(bool value) async {
    ppeLoading.value = true;
    final ok = await _ai.togglePpe(value);
    ppeEnabled.value = value;
    ppeLoading.value = false;
    await _ai.savePrefs(DetectionPrefs(ppe: value, fire: fireEnabled.value));
    if (!ok) mlOnline.value = false;
    if (ok) {
      SnackBarUtils.showSnackBar(
        value
            ? 'Helmet, vest, and mask violations will be detected.'
            : 'PPE detection has been turned off.',
        title: value ? '🦺 PPE Detection Enabled' : '🦺 PPE Detection Disabled',
      );
    } else {
      SnackBarUtils.showError('Could not reach the ML service.', title: 'PPE toggle failed');
    }
  }

  Future<void> toggleFire(bool value) async {
    fireLoading.value = true;
    final ok = await _ai.toggleFire(value);
    fireEnabled.value = value;
    fireLoading.value = false;
    await _ai.savePrefs(DetectionPrefs(ppe: ppeEnabled.value, fire: value));
    if (!ok) mlOnline.value = false;
    if (ok) {
      SnackBarUtils.showSnackBar(
        value
            ? 'Fire and smoke will be detected in camera feeds.'
            : 'Fire & smoke detection has been turned off.',
        title: value ? '🔥 Fire Detection Enabled' : '🔥 Fire Detection Disabled',
      );
    } else {
      SnackBarUtils.showError('Could not reach the ML service.', title: 'Fire toggle failed');
    }
  }

  // ── Navigation / account ───────────────────────────────────────────────────
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

  void navigateToCameraManagement() => Get.to(CameraManagementView(), binding: CameraManagementBinding());

  void navigateToHelp() => Get.to(HelpSupportView(), binding: HelpsupportBinding());

  void navigateToTerms() => Get.to(TermsPrivacyView(), binding: TermsprivacyBinding());

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
