import 'package:get/get.dart';

import '../modules/main/bindings/main_binding.dart';
import '../modules/main/camera_feed/bindings/camera_feed_binding.dart';
import '../modules/main/camera_feed/views/camera_feed_view.dart';
import '../modules/main/dashboard/bindings/dashboard_binding.dart';
import '../modules/main/dashboard/views/dashboard_view.dart';
import '../modules/main/views/main_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.DASHBOARD;

  static final routes = [
    GetPage(
      name: _Paths.MAIN,
      page: () => const MainView(),
      binding: MainBinding(),
      children: [
        GetPage(
          name: _Paths.CAMERA_FEED,
          page: () => const CameraFeedView(),
          binding: CameraFeedBinding(),
        ),
        GetPage(
          name: _Paths.DASHBOARD,
          page: () =>  DashboardView(),
          binding: DashboardBinding(),
        ),
      ],
    ),
  ];
}
