import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';
import '../controllers/camera_feed_controller.dart';

class CameraFeedView extends StatelessWidget {
  final CameraModel? camera;

  const CameraFeedView({super.key, this.camera});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CameraFeedController());
    controller.setCamera(camera);

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          controller.camera.value?.zone ?? "No Camera Selected",
        )),
      ),
      body: Obx(() {
        final cam = controller.camera.value;

        if (cam == null) {
          return _buildNullCameraUI(controller);
        }

        return _buildLiveCameraUI(cam);
      }),
    );
  }

  Widget _buildNullCameraUI(CameraFeedController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off, size: 90, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            "No Camera Selected",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: controller.retryOrSelectCamera,
            child: const Text("Select Camera"),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCameraUI(CameraModel cam) {
    return Center(
      child: Text(
        "Camera Live Feed - ${cam.id}",
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
