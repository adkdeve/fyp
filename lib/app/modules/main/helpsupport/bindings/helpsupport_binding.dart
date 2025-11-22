import 'package:get/get.dart';

import '../controllers/helpsupport_controller.dart';

class HelpsupportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HelpSupportController>(
      () => HelpSupportController(),
    );
  }
}
