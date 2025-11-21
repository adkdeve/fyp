import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/camera_model.dart';

class CameraManagementController extends GetxController {
  final cameras = <CameraModel>[].obs;
  final recordingStates = <String, bool>{}.obs; // RxMap for recording states

  @override
  void onInit() {
    super.onInit();
    loadCameras();
  }

  void loadCameras() {
    final sampleCameras = [
      CameraModel(
        id: "001",
        zone: "Zone A - Main Entrance",
        status: "online",
      ),
      CameraModel(
        id: "002",
        zone: "Zone B - Construction Area",
        status: "online",
      ),
      CameraModel(
        id: "003",
        zone: "Zone C - Storage Area",
        status: "offline",
      ),
      CameraModel(
        id: "004",
        zone: "Zone D - Scaffolding",
        status: "online",
      ),
    ];

    cameras.assignAll(sampleCameras);

    // Initialize recording states
    for (var camera in sampleCameras) {
      recordingStates[camera.id] = false;
    }
  }

  void toggleRecording(String cameraId) {
    if (recordingStates.containsKey(cameraId)) {
      recordingStates[cameraId] = !recordingStates[cameraId]!;
      recordingStates.refresh(); // This tells GetX to update observers
    } else {
      recordingStates[cameraId] = true;
      recordingStates.refresh();
    }

    // Show feedback
    final isRecording = recordingStates[cameraId]!;
    Get.snackbar(
      isRecording ? 'Recording Started' : 'Recording Stopped',
      'Camera $cameraId ${isRecording ? 'is now recording' : 'recording stopped'}',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
    );
  }

  void toggleStatus(String cameraId) {
    final index = cameras.indexWhere((cam) => cam.id == cameraId);
    if (index != -1) {
      final camera = cameras[index];
      final newStatus = camera.status.toLowerCase() == "online" ? "offline" : "online";
      cameras[index] = camera.copyWith(status: newStatus);

      // If disabling camera, also stop recording
      if (newStatus == "offline" && recordingStates[cameraId] == true) {
        recordingStates[cameraId] = false;
        recordingStates.refresh();
      }
    }
  }

  void handleViewFeed(CameraModel camera) {
    Get.snackbar(
      'Camera Feed',
      'Opening live feed for ${camera.name}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void handleAddCamera() {
    Get.dialog(
      AlertDialog(
        title: const Text('Add New Camera'),
        content: const Text(
            'This will guide you through:\n\n'
                '• Camera setup\n'
                '• Network configuration\n'
                '• AI model deployment'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Camera Setup',
                'Starting camera setup process...',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  bool isRecording(String cameraId) {
    return recordingStates[cameraId] ?? false;
  }

  int get onlineCount => cameras.where((c) => c.status.toLowerCase() == "online").length;
  int get recordingCount => recordingStates.values.where((isRecording) => isRecording).length;
  int get offlineCount => cameras.where((c) => c.status.toLowerCase() == "offline").length;
}