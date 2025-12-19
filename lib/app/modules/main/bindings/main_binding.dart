import 'package:construction_safety/app/modules/main/alerts/controllers/alerts_controller.dart';
import 'package:construction_safety/app/modules/main/analytics/controllers/analytics_controller.dart';
import 'package:construction_safety/app/modules/main/dashboard/controllers/dashboard_controller.dart';
import 'package:construction_safety/app/modules/main/history/controllers/history_controller.dart';
import 'package:construction_safety/app/modules/main/settings/controllers/settings_controller.dart';
import 'package:get/get.dart';
import '../controllers/main_controller.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(
      () => MainController(),
    );
    Get.lazyPut<DashboardController>(
      () => DashboardController(),
    );
    Get.lazyPut<AlertsController>(
      () => AlertsController(),
    );
    Get.lazyPut<HistoryController>(
      () => HistoryController(),
    );
    Get.lazyPut<AnalyticsController>(
      () => AnalyticsController(),
    );
    Get.lazyPut<SettingsController>(
      () => SettingsController(),
    );
  }
}
