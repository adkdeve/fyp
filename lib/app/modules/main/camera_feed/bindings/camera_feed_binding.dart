import 'package:get/get.dart';

import '../controllers/camera_feed_controller.dart';

class CameraFeedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CameraFeedController>(
      () => CameraFeedController(),
    );
  }
}
