import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';

class CameraFeedController extends GetxController {
  // Reactive variables
  var zoom = 1.0.obs;
  var isRecording = false.obs;
  var selectedCamera = Rxn<CameraModel>();
  var currentTime = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // Get selected camera from arguments
    if (Get.arguments != null) {
      selectedCamera.value = Get.arguments as CameraModel;
    } else {
      // Fallback to default camera
      selectedCamera.value = CameraModel(
        id: "CAM-001",
        zone: "Construction Site A",
        status: "online",
      );
    }

    // Update time every second
    updateTime();
    Timer.periodic(const Duration(seconds: 1), (_) => updateTime());
  }

  void updateTime() {
    final now = DateTime.now();
    currentTime.value = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  // Zoom controls
  void zoomIn() {
    if (zoom.value < 3.0) {
      zoom.value += 0.5;
    }
  }

  void zoomOut() {
    if (zoom.value > 1.0) {
      zoom.value -= 0.5;
    }
  }

  void resetZoom() {
    zoom.value = 1.0;
  }

  // Recording controls
  void toggleRecording() {
    isRecording.value = !isRecording.value;
  }

  void takeSnapshot() {
    Get.dialog(
      AlertDialog(
        title: const Text('Snapshot Captured'),
        content: const Text('Image saved to gallery.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void enterFullscreen() {
    Get.dialog(
      AlertDialog(
        title: const Text('Fullscreen Mode'),
        content: const Text('Entering fullscreen mode...'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void downloadRecording() {
    Get.dialog(
      AlertDialog(
        title: const Text('Download Recording'),
        content: const Text('Downloading last 30 minutes of footage...'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Detection status (for demonstration)
  bool get hasDetection => selectedCamera.value?.id == "CAM-002";
}