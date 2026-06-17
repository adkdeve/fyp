import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:construction_safety/utils/helpers/snackbar.dart';
import '../../../../data/models/violation_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/firestore_service.dart';
import '../../violation_detail/bindings/violation_detail_binding.dart';
import '../../violation_detail/views/violation_detail_view.dart';

class HistoryController extends GetxController {
  final FirestoreService _firestore = FirestoreService.to;
  final AuthService _auth = Get.find<AuthService>();

  final RxString searchTerm = ''.obs;
  final Rx<ViolationType?> filterType = Rx<ViolationType?>(null);
  final violations = <ViolationModel>[].obs;
  final isLoading = false.obs;
  final searchController = TextEditingController();

  // 🟢 Scroll Controller for Pagination
  final ScrollController scrollController = ScrollController();

  // Pagination
  int _offset = 0;
  static const int _pageSize = 50;
  final hasMore = true.obs;

  // Cache today's date to avoid creating instances inside the loop
  late DateTime _today;

  @override
  void onInit() {
    super.onInit();
    _updateTodayDate();
    searchController.addListener(_handleSearchChanged);

    // 🟢 Setup Scroll Listener for Infinite Scroll
    scrollController.addListener(_onScroll);
    loadHistoryData();
  }

  @override
  void onClose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    scrollController.dispose(); // 🟢 Dispose scroll controller
    super.onClose();
  }

  void _updateTodayDate() {
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
  }

  void _onScroll() {
    // Agar user bottom se 200 pixels door ho toh mazeed data load karo
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
      if (!isLoading.value && hasMore.value) {
        loadMore();
      }
    }
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

  Future<void> loadHistoryData({bool refresh = true}) async {
    if (refresh) {
      _offset = 0;
      hasMore.value = true;
      _updateTodayDate(); // Refresh today's date context
    }
    if (!hasMore.value || (isLoading.value && !refresh)) return;

    isLoading.value = true;
    try {
      final siteIds = await _getSiteIds();
      final cameraIds = await _getCameraIdsForSites(siteIds);
      final fetched = await _firestore.getViolations(
        q: searchTerm.value,
        cameraIds: cameraIds,
        limit: _pageSize,
        offset: _offset,
      );
      if (refresh) {
        violations.assignAll(fetched);
      } else {
        violations.addAll(fetched);
      }
      _offset += fetched.length;
      if (fetched.length < _pageSize) hasMore.value = false;
    } catch (e) {
      SnackBarUtils.showError('Failed to load violations: $e', title: 'Error');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() => loadHistoryData(refresh: false);

  // ── Optimized Date helpers (No more allocation loops) ──────────────────────
  String formatDate(DateTime dateTime) {
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (day == _today) return 'Today';
    if (day == _today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_monthAbbr(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
  }

  String formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _monthAbbr(int m) =>
      const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  // ── Filtering ──────────────────────────────────────────────────────────────
  List<ViolationModel> get filteredData {
    if (searchTerm.value.isEmpty && filterType.value == null) return violations;

    final searchLower = searchTerm.value.toLowerCase();
    return violations.where((item) {
      final matchesSearch =
          searchLower.isEmpty ||
          item.description.toLowerCase().contains(searchLower) ||
          item.zone.toLowerCase().contains(searchLower);
      final matchesFilter = filterType.value == null || item.type == filterType.value;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _handleSearchChanged() {
    // Adding a slight debounce or check to prevent spamming
    setSearchTerm(searchController.text);
  }

  // Search aur type filter ab client-side hote hain (filteredData getter mein).
  // getViolations() server-side q/type ignore karta hai, isliye re-fetch bekaar tha.
  void setSearchTerm(String value) {
    searchTerm.value = value;
  }

  void setFilterType(ViolationType? type) {
    filterType.value = type;
  }

  // Navigation & Export methods remain the same...
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
        SnackBarUtils.showSnackBar('Violations exported successfully', title: 'Export Ready');
      } else {
        SnackBarUtils.showError('Could not export violations', title: 'Export Failed');
      }
    } catch (e) {
      SnackBarUtils.showError(e.toString(), title: 'Export Failed');
    }
  }
}
