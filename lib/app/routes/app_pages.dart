import 'package:get/get.dart';

import '../modules/main/alerts/bindings/alerts_binding.dart';
import '../modules/main/alerts/views/alerts_view.dart';
import '../modules/main/analytics/bindings/analytics_binding.dart';
import '../modules/main/analytics/views/analytics_view.dart';
import '../modules/main/bindings/main_binding.dart';
import '../modules/main/camera_feed/bindings/camera_feed_binding.dart';
import '../modules/main/camera_feed/views/camera_feed_view.dart';
import '../modules/main/camera_management/bindings/camera_management_binding.dart';
import '../modules/main/camera_management/views/camera_management_view.dart';
import '../modules/main/dashboard/bindings/dashboard_binding.dart';
import '../modules/main/dashboard/views/dashboard_view.dart';
import '../modules/main/helpsupport/bindings/helpsupport_binding.dart';
import '../modules/main/helpsupport/views/helpsupport_view.dart';
import '../modules/main/history/bindings/history_binding.dart';
import '../modules/main/history/views/history_view.dart';
import '../modules/main/profile/bindings/profile_binding.dart';
import '../modules/main/profile/views/profile_view.dart';
import '../modules/main/settings/bindings/settings_binding.dart';
import '../modules/main/settings/views/settings_view.dart';
import '../modules/main/termsprivacy/bindings/termsprivacy_binding.dart';
import '../modules/main/termsprivacy/views/termsprivacy_view.dart';
import '../modules/main/views/main_view.dart';
import '../modules/main/violation_detail/bindings/violation_detail_binding.dart';
import '../modules/main/violation_detail/views/violation_detail_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.MAIN;

  static final routes = [
    GetPage(
      name: _Paths.MAIN,
      page: () => MainView(),
      binding: MainBinding(),
      children: [
        GetPage(
          name: _Paths.CAMERA_FEED,
          page: () => const CameraFeedView(),
          binding: CameraFeedBinding(),
        ),
        GetPage(
          name: _Paths.DASHBOARD,
          page: () => DashboardView(),
          binding: DashboardBinding(),
        ),
        GetPage(
          name: _Paths.ALERTS,
          page: () => AlertsView(),
          binding: AlertsBinding(),
        ),
        GetPage(
          name: _Paths.HISTORY,
          page: () => HistoryView(),
          binding: HistoryBinding(),
        ),
        GetPage(
          name: _Paths.ANALYTICS,
          page: () => const AnalyticsView(),
          binding: AnalyticsBinding(),
        ),
        GetPage(
          name: _Paths.SETTINGS,
          page: () => const SettingsView(),
          binding: SettingsBinding(),
        ),
        GetPage(
          name: _Paths.VIOLATION_DETAIL,
          page: () => const ViolationDetailView(),
          binding: ViolationDetailBinding(),
        ),
        GetPage(
          name: _Paths.CAMERA_MANAGEMENT,
          page: () => const CameraManagementView(),
          binding: CameraManagementBinding(),
        ),
        GetPage(
          name: _Paths.PROFILE,
          page: () => const ProfileView(),
          binding: ProfileBinding(),
        ),
        GetPage(
          name: _Paths.HELPSUPPORT,
          page: () => HelpSupportView(),
          binding: HelpsupportBinding(),
        ),
        GetPage(
          name: _Paths.TERMSPRIVACY,
          page: () => const TermsPrivacyView(),
          binding: TermsprivacyBinding(),
        ),
      ],
    ),
  ];
}
