// import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
// import 'package:get/get.dart';
// import '../../../../common/widgets/bottom_nav_item.dart';
// import '../../../core/core.dart';
// import '../controllers/main_controller.dart';
//
// class MainView extends GetView<MainController> {
//   const MainView({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Obx(
//       () => Scaffold(
//         resizeToAvoidBottomInset: true,
//         body: controller.currentView[controller.index.value],
//         bottomNavigationBar: _buildBottomNav(context),
//       ),
//     );
//   }
//
//   Widget _buildBottomNav(BuildContext context) {
//     return SafeArea(
//       top: false,
//       child: Container(
//         decoration: BoxDecoration(
//           color: Theme.of(context).brightness == Brightness.light
//               ? R.theme.white
//               : R.theme.color600,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.08),
//               offset: const Offset(0, -10),
//               blurRadius: 40,
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.symmetric(
//           vertical: AppConfig.defaultPadding / 2,
//         ),
//         child: Row(
//           children: [
//             const Spacer(),
//             _navItem(R.image.ic_home_un, R.image.ic_home, 0),
//             const Spacer(),
//             _navItem(R.image.ic_explore_un, R.image.ic_explore, 1),
//             const Spacer(),
//             _navItem(R.image.ic_application_un, R.image.ic_application, 2),
//             const Spacer(),
//             _navItem(R.image.ic_heart_un, R.image.ic_heart, 3),
//             const Spacer(),
//             _navItem(R.image.ic_profile_un, R.image.ic_profile, 4),
//             const Spacer(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _navItem(String icon, String activeIcon, int index) {
//     return MyBottomNavItem(
//       icon: icon,
//       activeicon: activeIcon,
//       active: controller.index.value == index,
//       onTap: () => controller.index.value = index,
//     );
//   }
//
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../alerts/views/alerts_view.dart';
import '../analytics/views/analytics_view.dart';
import '../camera_feed/views/camera_feed_view.dart';
import '../camera_management/views/camera_management_view.dart';
import '../controllers/main_controller.dart';
import '../dashboard/views/dashboard_view.dart';
import '../helpsupport/views/helpsupport_view.dart';
import '../history/views/history_view.dart';
import '../profile/views/profile_view.dart';
import '../settings/views/settings_view.dart';
import '../termsprivacy/views/termsprivacy_view.dart';
import '../violation_detail/views/violation_detail_view.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Obx(() => _buildCurrentScreen()),
      ),
      bottomNavigationBar: Obx(() {
        if (!controller.showBottomNav) return const SizedBox.shrink();

        return Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: BottomNavigationBar(
            currentIndex: _getCurrentIndex(),
            onTap: _onBottomNavTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF2563EB),
            unselectedItemColor: const Color(0xFF6B7280),
            selectedLabelStyle: const TextStyle(fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home, size: 20),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications, size: 20),
                    if (controller.activeViolationsCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            controller.activeViolationsCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Alerts',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.history, size: 20),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.analytics, size: 20),
                label: 'Analytics',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings, size: 20),
                label: 'Settings',
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentScreen() {
    switch (controller.activeScreen.value) {
      case Screen.dashboard:
        return  DashboardView();
      case Screen.alerts:
        return  AlertsView();
      case Screen.history:
        return const HistoryView();
      case Screen.analytics:
        return const AnalyticsView();
      case Screen.settings:
        return const SettingsView();
      case Screen.violationDetail:
        return const ViolationDetailView();
      case Screen.cameraManagement:
        return const CameraManagementView();
      case Screen.cameraFeed:
        return const CameraFeedView();
      case Screen.profile:
        return const ProfileView();
      case Screen.help:
        return const HelpSupportView();
      case Screen.terms:
        return const TermsPrivacyView();
      default:
        return DashboardView();
    }
  }

  int _getCurrentIndex() {
    switch (controller.activeScreen.value) {
      case Screen.dashboard:
        return 0;
      case Screen.alerts:
        return 1;
      case Screen.history:
        return 2;
      case Screen.analytics:
        return 3;
      case Screen.settings:
        return 4;
      default:
        return 0;
    }
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        controller.setActiveScreen(Screen.dashboard);
        break;
      case 1:
        controller.setActiveScreen(Screen.alerts);
        break;
      case 2:
        controller.setActiveScreen(Screen.history);
        break;
      case 3:
        controller.setActiveScreen(Screen.analytics);
        break;
      case 4:
        controller.setActiveScreen(Screen.settings);
        break;
    }
  }
}
