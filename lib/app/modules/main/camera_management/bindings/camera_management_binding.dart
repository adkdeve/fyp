import 'package:get/get.dart';

import '../controllers/camera_management_controller.dart';

class CameraManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CameraManagementController>(
      () => CameraManagementController(),
    );
  }
}
