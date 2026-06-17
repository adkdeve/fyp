import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import 'package:construction_safety/common/widgets/app_header.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColor.statusBar,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: AppColor.scaffoldBg,
          body: Column(
            children: [
              const AppHeader(
                title: 'Settings',
                subtitle: 'Manage your preferences and account settings',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileSection(),
                      const SizedBox(height: 16),
                      _buildAiDetectionControls(),
                      const SizedBox(height: 16),
                      _buildNotificationSettings(),
                      const SizedBox(height: 16),
                      _buildDisplaySettings(),
                      const SizedBox(height: 16),
                      _buildGeneralSettings(),
                      const SizedBox(height: 16),
                      _buildAppVersion(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile ─────────────────────────────────────────────────────────────────
  Widget _buildProfileSection() {
    return GestureDetector(
      onTap: controller.navigateToProfile,
      child: _card(
        children: [
          _sectionHeader('Profile'),
          Obx(() {
            final user = controller.currentUser.value;
            final avatarUrl = controller.resolvedAvatarUrl;
            return Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              width: 64,
                              height: 64,
                              errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                            )
                          : _buildAvatarFallback(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name.isNotEmpty == true ? user!.name : 'User',
                          style: Get.textTheme.titleMedium?.copyWith(
                            color: AppColor.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.role ?? 'Safety Officer',
                          style: Get.textTheme.bodyMedium?.copyWith(color: AppColor.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: Get.textTheme.bodySmall?.copyWith(color: AppColor.textTertiary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue, Colors.blueAccent],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          controller.userInitials,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── AI Detection Controls ────────────────────────────────────────────────────
  Widget _buildAiDetectionControls() {
    return _card(
      children: [
        // Header with ML service status badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColor.borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF4F46E5), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Detection Controls',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
                    ),
                  ),
                  Obx(() => _mlStatusBadge()),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Select which AI models to apply to all incoming camera feeds',
                style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
              ),
            ],
          ),
        ),
        Obx(() => _buildToggleRow(
              icon: Icons.health_and_safety,
              iconColor: Colors.amber[700]!,
              iconBgColor: AppColor.accentBadgeBg(Colors.amber),
              title: 'PPE Detection',
              subtitle: 'Detect missing helmets, vests & masks on workers',
              value: controller.ppeEnabled.value,
              onChanged: controller.mlChecked.value ? (v) => controller.togglePpe(v) : null,
              loading: controller.ppeLoading.value,
              showActiveBadge: true,
            )),
        Obx(() => _buildToggleRow(
              icon: Icons.local_fire_department,
              iconColor: Colors.red,
              iconBgColor: AppColor.accentBadgeBg(Colors.red),
              title: 'Fire & Smoke Detection',
              subtitle: 'Identify fire or smoke hazards in camera feeds',
              value: controller.fireEnabled.value,
              onChanged: controller.mlChecked.value ? (v) => controller.toggleFire(v) : null,
              loading: controller.fireLoading.value,
              showActiveBadge: true,
              isLast: true,
            )),
      ],
    );
  }

  Widget _mlStatusBadge() {
    if (!controller.mlChecked.value) {
      return _badge('Checking…', AppColor.textTertiary, AppColor.subtleBg, icon: Icons.sync);
    }
    return controller.mlOnline.value
        ? _badge('ML Service Online', const Color(0xFF059669), const Color(0xFFD1FAE5), icon: Icons.wifi)
        : _badge('ML Service Offline', const Color(0xFFDC2626), const Color(0xFFFEE2E2), icon: Icons.wifi_off);
  }

  Widget _badge(String text, Color fg, Color bg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  // ── Notifications (web-style: Alert Pop-ups, Push, Sound) ────────────────────
  Widget _buildNotificationSettings() {
    return _card(
      children: [
        _sectionHeader('Notifications'),
        Obx(() => _buildToggleRow(
              icon: Icons.notifications_active,
              iconColor: Colors.indigo,
              iconBgColor: AppColor.accentBadgeBg(Colors.indigo),
              title: 'Alert Pop-ups',
              subtitle: 'Show in-app notifications when a PPE violation is detected',
              value: controller.alertPopups.value,
              onChanged: (v) => controller.toggleAlertPopups(v),
            )),
        // Push notifications — device-level notifications on new violations
        Obx(() => _buildToggleRow(
              icon: Icons.phone_android,
              iconColor: Colors.deepPurple,
              iconBgColor: AppColor.accentBadgeBg(Colors.deepPurple),
              title: 'Push Notifications',
              subtitle: 'Show device notifications for new violations',
              value: controller.pushNotifications.value,
              onChanged: (v) => controller.togglePushNotifications(v),
            )),
        Obx(() => _buildToggleRow(
              icon: Icons.volume_up,
              iconColor: Colors.teal,
              iconBgColor: AppColor.accentBadgeBg(Colors.teal),
              title: 'Sound Alerts',
              subtitle: 'Play a sound when a critical violation pop-up appears',
              value: controller.soundAlerts.value,
              onChanged: (v) => controller.toggleSoundAlerts(v),
              isLast: true,
            )),
      ],
    );
  }

  // ── Display (Dark Mode) ──────────────────────────────────────────────────────
  Widget _buildDisplaySettings() {
    return _card(
      children: [
        _sectionHeader('Display'),
        Obx(() => _buildToggleRow(
              icon: Icons.dark_mode,
              iconColor: Colors.blue,
              iconBgColor: AppColor.accentBadgeBg(Colors.blue),
              title: 'Dark Mode',
              subtitle: 'Enable dark theme across the portal',
              value: controller.isDarkMode.value,
              onChanged: (v) => controller.toggleDarkMode(v),
              isLast: true,
            )),
      ],
    );
  }

  // ── Generic toggle row ───────────────────────────────────────────────────────
  Widget _buildToggleRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    bool loading = false,
    bool showActiveBadge = false,
    bool dimmed = false,
    bool isLast = false,
  }) {
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: AppColor.borderColor)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColor.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                ],
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (showActiveBadge && value)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _badge('Active', const Color(0xFF059669), const Color(0xFFD1FAE5)),
              ),
            Switch(value: value, onChanged: onChanged, activeColor: Colors.blue),
          ],
        ),
      ),
    );
  }

  // ── General ──────────────────────────────────────────────────────────────────
  Widget _buildGeneralSettings() {
    return _card(
      children: [
        _sectionHeader('General'),
        _buildGeneralItem(
          icon: Icons.videocam_outlined,
          title: 'Camera Management',
          onTap: controller.navigateToCameraManagement,
        ),
        _buildGeneralItem(icon: Icons.help_outline, title: 'Help & Support', onTap: controller.navigateToHelp),
        _buildGeneralItem(icon: Icons.description, title: 'Terms & Privacy', onTap: controller.navigateToTerms),
        _buildGeneralItem(
          icon: Icons.logout,
          title: 'Log Out',
          titleColor: Colors.red,
          onTap: controller.handleLogout,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildGeneralItem({
    required IconData icon,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: AppColor.borderColor)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColor.subtleBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: titleColor == Colors.red ? Colors.red : AppColor.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: titleColor ?? AppColor.textPrimary)),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return const Column(
      children: [
        Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
        SizedBox(height: 4),
        Text('AI Construction Safety Monitor', style: TextStyle(fontSize: 12, color: Colors.grey)),
        SizedBox(height: 4),
        Text('© 2024 BuildSafe Technologies', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ── Shared layout helpers ────────────────────────────────────────────────────
  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.borderColor)),
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary),
      ),
    );
  }
}
