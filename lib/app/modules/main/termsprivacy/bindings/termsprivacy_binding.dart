import 'package:get/get.dart';

import '../controllers/termsprivacy_controller.dart';

class TermsprivacyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TermsPrivacyController>(
      () => TermsPrivacyController(),
    );
  }
}
