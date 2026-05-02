import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/values/apis_url.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/safety_api_service.dart';
import '../../controllers/main_controller.dart';
import '../../history/controllers/history_controller.dart';
import '../../violation_detail/bindings/violation_detail_binding.dart';
import '../../violation_detail/views/violation_detail_view.dart';

class AlertsController extends GetxController {
  final SafetyApiService _api = SafetyApiService.to;
  final AuthService _auth = Get.find<AuthService>();
  final MainController _main = Get.find<MainController>();

  final RxList<ViolationModel> violations = <ViolationModel>[].obs;
  final Rxn<ViolationModel> selectedViolation = Rxn<ViolationModel>();
  final isLoading = false.obs;
  final searchTerm = ''.obs;
  final Rx<ViolationSeverity?> severityFilter = Rx<ViolationSeverity?>(null);
  final searchController = TextEditingController();

  WebSocketChannel? _wsChannel;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_handleSearchChanged);
    fetchAlerts();
    _connectWebSocket();
  }

  @override
  void onClose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    _wsChannel?.sink.close();
    super.onClose();
  }

  Future<void> fetchAlerts({bool unreadOnly = false}) async {
    isLoading.value = true;
    try {
      final raw = await _api.getViolations(
        status: 'open',
        enabledOnly: true,
        q: searchTerm.value,
        severity: _severityToBackend(severityFilter.value),
        limit: 200,
      );
      violations.assignAll(
        raw.map((e) => ViolationModel.fromJson(e as Map<String, dynamic>)).toList(),
      );
      if (!unreadOnly &&
          searchTerm.value.isEmpty &&
          severityFilter.value == null) {
        _main.setViolations(violations);
      }
    } catch (e) {
      Get.snackbar(
        'Alerts Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      final token = await _auth.getToken();
      if (token == null) return;
      _wsChannel = WebSocketChannel.connect(Uri.parse(ApisUrl.wsAlerts(token)));
      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            if (data['type'] == 'new_violation') {
              final violationMap = <String, dynamic>{
                'id': data['violation_id'],
                'type': data['violation_type'],
                'severity': data['severity'],
                'detected_at': data['detected_at'],
                'snapshot_url': data['snapshot_url'],
                'status': 'open',
                'camera_id': data['camera_id'],
                'camera': {
                  'name': 'Camera ${data['camera_id']}',
                  'location': null,
                },
              };
              final v = ViolationModel.fromJson(violationMap);
              violations.insert(0, v);
              _main.upsertViolation(v);
              if (Get.isRegistered<HistoryController>()) {
                Get.find<HistoryController>().applyViolationUpdate(v);
              }
              Get.snackbar(
                'New Violation',
                v.description,
                snackPosition: SnackPosition.TOP,
                duration: const Duration(seconds: 4),
              );
            }
          } catch (_) {}
        },
        onError: (_) => _reconnectAfterDelay(),
        onDone: () => _reconnectAfterDelay(),
      );
    } catch (_) {}
  }

  void _reconnectAfterDelay() {
    Future.delayed(const Duration(seconds: 5), () async {
      await _api.tryRefreshToken();
      _connectWebSocket();
    });
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllAlertsRead();
      await fetchAlerts();
      Get.snackbar(
        'Done',
        'All alerts marked as read',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  List<ViolationModel> get activeAlerts =>
      violations.where((v) => v.status == ViolationStatus.active).toList();

  void _handleSearchChanged() {
    setSearchTerm(searchController.text);
  }

  void setSearchTerm(String value) {
    if (searchTerm.value == value) return;
    searchTerm.value = value;
    fetchAlerts();
  }

  void setSeverityFilter(ViolationSeverity? severity) {
    severityFilter.value = severity;
    fetchAlerts();
  }

  void viewDetails(ViolationModel violation) {
    selectedViolation.value = violation;
    _main.setSelectedViolation(violation);
    Get.to(
      () => const ViolationDetailView(),
      arguments: violation,
      binding: ViolationDetailBinding(),
    );
  }

  int countBySeverity(ViolationSeverity s) =>
      activeAlerts.where((v) => v.severity == s).length;

  Future<void> dismissAlert(String id) async {
    final i = violations.indexWhere((v) => v.id == id);
    if (i == -1) return;
    try {
      final intId = int.tryParse(id);
      if (intId != null) {
        await _api.resolveViolation(intId, 'false_positive');
      }
      final updated = violations[i].copyWith(status: ViolationStatus.dismissed);
      violations[i] = updated;
      violations.refresh();
      _main.upsertViolation(updated);
      if (Get.isRegistered<HistoryController>()) {
        Get.find<HistoryController>().applyViolationUpdate(updated);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> acknowledgeAlert(String id) async {
    final i = violations.indexWhere((v) => v.id == id);
    if (i == -1) return;
    try {
      final intId = int.tryParse(id);
      if (intId != null) {
        await _api.resolveViolation(intId, 'acknowledged');
      }
      final updated = violations[i].copyWith(
        status: ViolationStatus.acknowledged,
        acknowledgedBy: 'Supervisor',
      );
      violations[i] = updated;
      violations.refresh();
      _main.upsertViolation(updated);
      if (Get.isRegistered<HistoryController>()) {
        Get.find<HistoryController>().applyViolationUpdate(updated);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  void applyViolationUpdate(ViolationModel updated) {
    final index = violations.indexWhere((v) => v.id == updated.id);
    if (index != -1) {
      violations[index] = updated;
      violations.refresh();
      return;
    }

    final matchesSearch =
        searchTerm.value.isEmpty ||
        updated.description.toLowerCase().contains(
          searchTerm.value.toLowerCase(),
        ) ||
        updated.zone.toLowerCase().contains(searchTerm.value.toLowerCase());
    final matchesSeverity =
        severityFilter.value == null || updated.severity == severityFilter.value;

    if (updated.status == ViolationStatus.active &&
        matchesSearch &&
        matchesSeverity) {
      violations.insert(0, updated);
    }
  }

  String? _severityToBackend(ViolationSeverity? severity) {
    switch (severity) {
      case ViolationSeverity.high:
        return 'high';
      case ViolationSeverity.medium:
        return 'medium';
      case ViolationSeverity.low:
        return 'low';
      case null:
        return null;
    }
  }
}
