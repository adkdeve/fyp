import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/violation_model.dart';
import '../../../../data/services/firestore_service.dart';
import '../../controllers/main_controller.dart';
import '../../history/controllers/history_controller.dart';
import '../../violation_detail/bindings/violation_detail_binding.dart';
import '../../violation_detail/views/violation_detail_view.dart';

class AlertsController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final MainController _main = Get.find<MainController>();

  final RxList<ViolationModel> violations = <ViolationModel>[].obs;
  final Rxn<ViolationModel> selectedViolation = Rxn<ViolationModel>();
  final isLoading = false.obs;
  final searchTerm = ''.obs;
  final Rx<ViolationSeverity?> severityFilter = Rx<ViolationSeverity?>(null);
  final searchController = TextEditingController();

  late StreamSubscription<List<ViolationModel>> _violationsSubscription;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_handleSearchChanged);
    _initializeViolationsStream();
  }

  @override
  void onClose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    _violationsSubscription.cancel();
    super.onClose();
  }

  void _initializeViolationsStream() {
    _violationsSubscription = _firestore
        .getViolationsStream(
          status: 'open',
          severity: _severityToBackend(severityFilter.value),
          limit: 200,
        )
        .listen(
          (violationsList) {
            violations.assignAll(violationsList);
            if (searchTerm.value.isEmpty) {
              _main.setViolations(violationsList);
            }
          },
          onError: (e) {
            Get.snackbar(
              'Stream Error',
              'Could not load alerts: $e',
              snackPosition: SnackPosition.BOTTOM,
            );
          },
        );
  }

  Future<void> fetchAlerts({bool unreadOnly = false}) async {
    isLoading.value = true;
    try {
      final raw = await _firestore.getViolations(
        status: 'open',
        severity: _severityToBackend(severityFilter.value),
        limit: 200,
      );
      violations.assignAll(raw);
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

  Future<void> markAllRead() async {
    try {
      await _firestore.markAllAlertsRead();
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
    // Filter locally instead of fetching
    if (value.isEmpty && severityFilter.value == null) {
      _initializeViolationsStream();
    }
  }

  void setSeverityFilter(ViolationSeverity? severity) {
    severityFilter.value = severity;
    _violationsSubscription.cancel();
    _initializeViolationsStream();
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
      await _firestore.resolveViolation(id, status: 'false_positive');
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
      await _firestore.resolveViolation(id, status: 'acknowledged');
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
