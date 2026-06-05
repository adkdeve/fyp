import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/firestore_service.dart';
import '../../violation_detail/bindings/violation_detail_binding.dart';
import '../../violation_detail/views/violation_detail_view.dart';

class HistoryController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;

  final RxString searchTerm = ''.obs;
  final Rx<ViolationType?> filterType = Rx<ViolationType?>(null);
  final violations = <ViolationModel>[].obs;
  final isLoading = false.obs;
  final searchController = TextEditingController();

  // Pagination
  int _offset = 0;
  static const int _pageSize = 50;
  final hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(_handleSearchChanged);
    loadHistoryData();
  }

  @override
  void onClose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadHistoryData({bool refresh = true}) async {
    if (refresh) {
      _offset = 0;
      hasMore.value = true;
    }
    if (!hasMore.value) return;
    isLoading.value = true;
    try {
      final raw = await _firestore.getViolations(q: searchTerm.value, limit: _pageSize, offset: _offset);
      final fetched = raw;
      if (refresh) {
        violations.assignAll(fetched);
      } else {
        violations.addAll(fetched);
      }
      _offset += fetched.length;
      if (fetched.length < _pageSize) hasMore.value = false;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load violations: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() => loadHistoryData(refresh: false);

  // ── Date helpers ───────────────────────────────────────────────────────────
  String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_monthAbbr(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
  }

  String formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _monthAbbr(int m) =>
      const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  // ── Filtering ──────────────────────────────────────────────────────────────
  List<ViolationModel> get filteredData {
    return violations.where((item) {
      final matchesSearch =
          item.description.toLowerCase().contains(searchTerm.value.toLowerCase()) ||
          item.zone.toLowerCase().contains(searchTerm.value.toLowerCase());
      final matchesFilter = filterType.value == null || item.type == filterType.value;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _handleSearchChanged() {
    setSearchTerm(searchController.text);
  }

  void setSearchTerm(String value) {
    if (searchTerm.value == value) return;
    searchTerm.value = value;
    loadHistoryData();
  }

  void setFilterType(ViolationType? type) {
    filterType.value = type;
    loadHistoryData();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void viewViolationDetails(ViolationModel violation) {
    Get.to(() => const ViolationDetailView(), arguments: violation, binding: ViolationDetailBinding());
  }

  void applyViolationUpdate(ViolationModel updated) {
    final index = violations.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      violations[index] = updated;
      violations.refresh();
      return;
    }
    violations.insert(0, updated);
  }

  Future<void> exportData() async {
    try {
      final success = await _firestore.exportViolations({'q': searchTerm.value});
      if (success) {
        Get.snackbar('Export Ready', 'Violations exported successfully', snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('Export Failed', 'Could not export violations', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Export Failed', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }
}
