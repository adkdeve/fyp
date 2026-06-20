import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:construction_safety/utils/helpers/snackbar.dart';

import '../../../../core/values/apis_url.dart';
import '../../../../data/models/camera_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../camera_feed/bindings/camera_feed_binding.dart';
import '../../camera_feed/views/camera_feed_view.dart';
import '../../controllers/main_controller.dart';

class CameraManagementController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final AuthService _auth = Get.find<AuthService>();
  final MainController _main = Get.find<MainController>();
  final http.Client _client = http.Client();

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
    _client.close();
    super.onClose();
  }

  Future<void> loadCameras() async {
    isLoading.value = true;
    try {
      // Web jaisा: sirf officer ke assigned sites ki cameras
      final siteIds = await _auth.getUserSiteIds();
      final raw = await _firestore.getCameras(siteIds: siteIds);
      cameras.assignAll(raw);
      _main.setCameras(cameras);
    } catch (e) {
      SnackBarUtils.showError('Failed to load cameras: $e', title: 'Error');
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
      SnackBarUtils.showError(
        'Enable this camera to start monitoring its feed.',
        title: 'Camera Disabled',
      );
      return;
    }
    Get.to(() => const CameraFeedView(), arguments: camera, binding: CameraFeedBinding());
  }

  Future<void> toggleStatus(dynamic cameraId) async {
    if (!ConnectivityService.to.online) {
      SnackBarUtils.showError(
        'You need an internet connection to start or stop a camera.',
        title: 'No Connection',
      );
      return;
    }
    final id = cameraId.toString();
    // Firebase IDs string hote hain — toString se compare karo (int bug fix)
    final i = cameras.indexWhere((c) => c.id.toString() == id);
    if (i == -1) return;
    final current = cameras[i];
    final newEnabled = !current.enabled;
    try {
      final success = await _firestore.updateCamera(id, {'enabled': newEnabled});
      if (!success) return;

      final updated = current.copyWith(enabled: newEnabled);
      cameras[i] = updated;
      cameras.refresh();
      _main.upsertCamera(updated);

      // Backend camera worker ko actually start/stop karo (web jaisा)
      if (newEnabled) {
        await _startCamera(id, current.rtspUrl);
        SnackBarUtils.showSnackBar('Live feed for ${current.name} is now running.', title: 'Camera Started');
      } else {
        await _stopCamera(id);
        SnackBarUtils.showSnackBar('Live feed for ${current.name} stopped.', title: 'Camera Stopped');
      }
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Error');
    }
  }

  /// Backend par camera worker start (inference + streaming).
  Future<void> _startCamera(String id, String rtspUrl) async {
    try {
      await _client
          .post(
            Uri.parse(ApisUrl.cameraStart),
            headers: {'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true'},
            body: jsonEncode({'camera_id': id, 'rtsp_url': rtspUrl}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Non-fatal — Firestore flag already update ho chuka hai
    }
  }

  /// Backend par camera worker stop.
  Future<void> _stopCamera(String id) async {
    try {
      await _client
          .post(
            Uri.parse(ApisUrl.cameraStop(id)),
            headers: {'bypass-tunnel-reminder': 'true'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  int get onlineCount => cameras.where((c) => c.status.toLowerCase() == 'online').length;
  int get enabledCount => cameras.where((c) => c.enabled).length;
  int get disabledCount => cameras.where((c) => !c.enabled).length;
  int get offlineCount => cameras.where((c) => c.status.toLowerCase() != 'online').length;
}
