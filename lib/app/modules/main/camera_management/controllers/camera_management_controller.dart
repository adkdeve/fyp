import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/camera_model.dart';
import '../../../../data/services/firestore_service.dart';
import '../../camera_feed/bindings/camera_feed_binding.dart';
import '../../camera_feed/views/camera_feed_view.dart';
import '../../controllers/main_controller.dart';

class CameraManagementController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final MainController _main = Get.find<MainController>();

  final cameras = <CameraModel>[].obs;
  final isLoading = false.obs;
  final searchTerm = ''.obs;
  final statusFilter = 'all'.obs;
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_handleSearchChanged);
    loadCameras();
  }

  @override
  void onClose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadCameras() async {
    isLoading.value = true;
    try {
      final raw = await _firestore.getCameras();
      cameras.assignAll(raw);
      _main.setCameras(cameras);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load cameras: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  List<CameraModel> get filteredCameras {
    return cameras.where((camera) {
      final q = searchTerm.value.toLowerCase();
      final matchesSearch = q.isEmpty || camera.name.toLowerCase().contains(q) || camera.zone.toLowerCase().contains(q);
      final matchesStatus = statusFilter.value == 'all' || camera.status.toLowerCase() == statusFilter.value;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _handleSearchChanged() {
    setSearchTerm(searchController.text);
  }

  void setSearchTerm(String value) {
    if (searchTerm.value == value) return;
    searchTerm.value = value;
  }

  void setStatusFilter(String value) => statusFilter.value = value;

  void handleViewFeed(CameraModel camera) {
    if (!camera.enabled) {
      Get.snackbar(
        'Camera Disabled',
        'Enable this camera to start monitoring its feed.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.to(() => const CameraFeedView(), arguments: camera, binding: CameraFeedBinding());
  }

  Future<void> toggleStatus(int cameraId) async {
    final i = cameras.indexWhere((c) => c.id == cameraId);
    if (i == -1) return;
    final current = cameras[i];
    try {
      final success = await _firestore.updateCamera(cameraId.toString(), {'enabled': !current.enabled});
      if (success) {
        final updated = current.copyWith(enabled: !current.enabled);
        cameras[i] = updated;
        cameras.refresh();
        _main.upsertCamera(updated);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  int get onlineCount => cameras.where((c) => c.status.toLowerCase() == 'online').length;
  int get enabledCount => cameras.where((c) => c.enabled).length;
  int get disabledCount => cameras.where((c) => !c.enabled).length;
  int get offlineCount => cameras.where((c) => c.status.toLowerCase() != 'online').length;
}
