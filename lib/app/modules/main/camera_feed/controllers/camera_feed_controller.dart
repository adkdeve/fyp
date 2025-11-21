import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';

class CameraFeedController extends GetxController {
  Rx<CameraModel?> camera = Rx<CameraModel?>(null);

  void setCamera(CameraModel? newCamera) {
    camera.value = newCamera;
  }

  void retryOrSelectCamera() {
    // Show dialog or navigate to camera selection screen
    Get.snackbar("No camera selected", "Please select a valid camera.");
  }
}
