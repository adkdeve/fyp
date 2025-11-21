import 'package:get/get.dart';

import '../controllers/violation_detail_controller.dart';

class ViolationDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ViolationDetailController>(
      () => ViolationDetailController(),
    );
  }
}
