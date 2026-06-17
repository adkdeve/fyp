import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:construction_safety/utils/helpers/snackbar.dart';

import '../../../../data/models/violation_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../controllers/main_controller.dart';
import '../../history/controllers/history_controller.dart';
import '../../violation_detail/bindings/violation_detail_binding.dart';
import '../../violation_detail/views/violation_detail_view.dart';

class AlertsController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final AuthService _auth = Get.find<AuthService>();
  final MainController _main = Get.find<MainController>();

  final RxList<ViolationModel> violations = <ViolationModel>[].obs;
  final Rxn<ViolationModel> selectedViolation = Rxn<ViolationModel>();
  final isLoading = false.obs;
  final searchTerm = ''.obs;
  final Rx<ViolationSeverity?> severityFilter = Rx<ViolationSeverity?>(null);
  final searchController = TextEditingController();

  // 🟢 SCROLL CONTROLLER ADDED
  final ScrollController scrollController = ScrollController();

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
    scrollController.dispose(); // 🟢 MEMORY LEAK SE BACHNE KE LIYE DISPOSE
    super.onClose();
  }

  Future<List<String>?> _getSiteIds() async {
    final siteIds = await _auth.getUserSiteIds();
    return siteIds == null || siteIds.isEmpty ? null : siteIds;
  }

  Future<List<String>?> _getCameraIdsForSites(List<String>? siteIds) async {
    if (siteIds == null || siteIds.isEmpty) return null;
    final cameraIds = await _firestore.getCameraIdsBySiteIds(siteIds);
    return cameraIds.isEmpty ? null : cameraIds;
  }

  void _initializeViolationsStream() async {
    final siteIds = await _getSiteIds();
    final cameraIds = await _getCameraIdsForSites(siteIds);
    _violationsSubscription = _firestore
        .getViolationsStream(
          cameraIds: cameraIds,
          status: 'open',
          severity: null,
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
            SnackBarUtils.showError('Could not load alerts: $e', title: 'Stream Error');
          },
        );
  }

  Future<void> fetchAlerts({bool unreadOnly = false}) async {
    isLoading.value = true;
    try {
      final siteIds = await _getSiteIds();
      final cameraIds = await _getCameraIdsForSites(siteIds);
      final raw = await _firestore.getViolations(
        cameraIds: cameraIds,
        status: 'open',
        severity: null,
        limit: 200,
      );
      violations.assignAll(raw);
      if (!unreadOnly && searchTerm.value.isEmpty && severityFilter.value == null) {
        _main.setViolations(violations);
      }
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Alerts Error');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAllRead() async {
    try {
      await _firestore.markAllAlertsRead();
      await fetchAlerts();
      SnackBarUtils.showSnackBar('All alerts marked as read', title: 'Done');
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Error');
    }
  }

  /// Saari active (open) alerts — bina search/severity filter ke (counts ke liye).
  List<ViolationModel> get _activeBase => violations.where((v) => v.status == ViolationStatus.active).toList();

  /// Display list — active + severity filter + search term (sab client-side).
  List<ViolationModel> get activeAlerts {
    final term = searchTerm.value.toLowerCase().trim();
    final sev = severityFilter.value;
    return _activeBase.where((v) {
      if (sev != null && v.severity != sev) return false;
      if (term.isEmpty) return true;
      return v.description.toLowerCase().contains(term) ||
          v.zone.toLowerCase().contains(term) ||
          v.type.name.toLowerCase().contains(term);
    }).toList();
  }

  void _handleSearchChanged() {
    setSearchTerm(searchController.text);
  }

  void setSearchTerm(String value) {
    if (searchTerm.value == value) return;
    searchTerm.value = value; // client-side filter — koi re-subscribe nahi
  }

  void setSeverityFilter(ViolationSeverity? severity) {
    severityFilter.value = severity;
  }

  void viewDetails(ViolationModel violation) {
    selectedViolation.value = violation;
    _main.setSelectedViolation(violation);
    Get.to(() => const ViolationDetailView(), arguments: violation, binding: ViolationDetailBinding());
  }

  int countBySeverity(ViolationSeverity s) => _activeBase.where((v) => v.severity == s).length;

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
      SnackBarUtils.showError(e.toString(), title: 'Error');
    }
  }

  Future<void> acknowledgeAlert(String id) async {
    final i = violations.indexWhere((v) => v.id == id);
    if (i == -1) return;
    try {
      await _firestore.resolveViolation(id, status: 'acknowledged');
      final updated = violations[i].copyWith(status: ViolationStatus.acknowledged, acknowledgedBy: 'Supervisor');
      violations[i] = updated;
      violations.refresh();
      _main.upsertViolation(updated);
      if (Get.isRegistered<HistoryController>()) {
        Get.find<HistoryController>().applyViolationUpdate(updated);
      }
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Error');
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
        updated.description.toLowerCase().contains(searchTerm.value.toLowerCase()) ||
        updated.zone.toLowerCase().contains(searchTerm.value.toLowerCase());
    final matchesSeverity = severityFilter.value == null || updated.severity == severityFilter.value;

    if (updated.status == ViolationStatus.active && matchesSearch && matchesSeverity) {
      violations.insert(0, updated);
    }
  }

}
