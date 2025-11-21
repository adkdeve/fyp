import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../../common/widgets/bottom_nav_item.dart';
import '../../../core/core.dart';
import '../controllers/main_controller.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        resizeToAvoidBottomInset: true,
        body: controller.currentView[controller.index.value],
        bottomNavigationBar: _buildBottomNav(context),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? R.theme.white
              : R.theme.color600,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, -10),
              blurRadius: 40,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          vertical: AppConfig.defaultPadding / 2,
        ),
        child: Row(
          children: [
            const Spacer(),
            _navItem(R.image.ic_home_un, R.image.ic_home, 0),
            const Spacer(),
            _navItem(R.image.ic_explore_un, R.image.ic_explore, 1),
            const Spacer(),
            _navItem(R.image.ic_application_un, R.image.ic_application, 2),
            const Spacer(),
            _navItem(R.image.ic_heart_un, R.image.ic_heart, 3),
            const Spacer(),
            _navItem(R.image.ic_profile_un, R.image.ic_profile, 4),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String icon, String activeIcon, int index) {
    return MyBottomNavItem(
      icon: icon,
      activeicon: activeIcon,
      active: controller.index.value == index,
      onTap: () => controller.index.value = index,
    );
  }

}
