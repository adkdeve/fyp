import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/camera_model.dart';
import '../../../../data/services/safety_api_service.dart';
import '../../camera_feed/bindings/camera_feed_binding.dart';
import '../../camera_feed/views/camera_feed_view.dart';

class CameraManagementController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;

  final cameras = <CameraModel>[].obs;
  final isLoading = false.obs;
  final searchTerm = ''.obs;
  final statusFilter = 'all'.obs;
  final recordingStates = <int, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadCameras();
  }

  Future<void> loadCameras() async {
    isLoading.value = true;
    try {
      final raw = await _api.getCameras();
      cameras.assignAll(raw.map((e) => CameraModel.fromJson(e)).toList());
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load cameras: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<CameraModel> get filteredCameras {
    return cameras.where((camera) {
      final q = searchTerm.value.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          camera.name.toLowerCase().contains(q) ||
          camera.zone.toLowerCase().contains(q);
      final matchesStatus =
          statusFilter.value == 'all' ||
          camera.status.toLowerCase() == statusFilter.value;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void setSearchTerm(String value) => searchTerm.value = value;
  void setStatusFilter(String value) => statusFilter.value = value;

  void toggleRecording(int cameraId) {
    CameraModel? camera;
    for (final item in cameras) {
      if (item.id == cameraId) {
        camera = item;
        break;
      }
    }
    if (camera != null) handleViewFeed(camera);
  }

  bool isRecording(int cameraId) => recordingStates[cameraId] ?? false;

  void handleViewFeed(CameraModel camera) {
    Get.to(
      () => const CameraFeedView(),
      arguments: camera,
      binding: CameraFeedBinding(),
    );
  }

  void handleAddCamera() {
    final nameCtrl = TextEditingController();
    final rtspCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Add New Camera'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: rtspCtrl,
              decoration: const InputDecoration(labelText: 'RTSP URL'),
            ),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await _createCamera(
                name: nameCtrl.text.trim(),
                rtspUrl: rtspCtrl.text.trim(),
                location: locationCtrl.text.trim().isEmpty
                    ? null
                    : locationCtrl.text.trim(),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCamera({
    required String name,
    required String rtspUrl,
    String? location,
  }) async {
    if (name.isEmpty || rtspUrl.isEmpty) {
      Get.snackbar(
        'Validation',
        'Name and RTSP URL are required',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      await _api.createCamera({
        'name': name,
        'rtsp_url': rtspUrl,
        if (location != null) 'location': location,
        'enabled': true,
      });
      await loadCameras();
      Get.snackbar(
        'Success',
        'Camera "$name" added',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> toggleStatus(int cameraId) async {
    final i = cameras.indexWhere((c) => c.id == cameraId);
    if (i == -1) return;
    final current = cameras[i];
    try {
      final raw = await _api.updateCamera(cameraId, {
        'enabled': !current.enabled,
      });
      cameras[i] = CameraModel.fromJson(raw);
      cameras.refresh();
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  int get onlineCount =>
      cameras.where((c) => c.status.toLowerCase() == 'online').length;
  int get offlineCount =>
      cameras.where((c) => c.status.toLowerCase() != 'online').length;
  int get recordingCount => recordingStates.values.where((v) => v).length;
}
