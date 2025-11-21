import 'package:get/get.dart';

import '../../../../data/models/violation_model.dart';
import '../../violation_detail/bindings/violation_detail_binding.dart';
import '../../violation_detail/views/violation_detail_view.dart';

class HistoryController extends GetxController {
  final RxString searchTerm = ''.obs;
  final Rx<ViolationType?> filterType = Rx<ViolationType?>(null);

  final violations = <ViolationModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadHistoryData();
  }

  void loadHistoryData() {
    // Sample data using your exact model
    final sampleData = [
      ViolationModel(
        id: "V004",
        type: ViolationType.Hazardous,
        zone: "Zone C - Storage Area",
        description: "Worker too close to hazardous zone",
        time: DateTime(2024, 11, 18, 16, 20),
        status: ViolationStatus.resolved,
        severity: ViolationSeverity.high,
      ),
      ViolationModel(
        id: "V005",
        type: ViolationType.Material,
        zone: "Zone B - Construction Area",
        description: "Incorrect material placement",
        time: DateTime(2024, 11, 18, 14, 55),
        status: ViolationStatus.dismissed,
        severity: ViolationSeverity.medium,
      ),
      ViolationModel(
        id: "V006",
        type: ViolationType.PPE,
        zone: "Zone A - Main Entrance",
        description: "Safety gloves not worn properly",
        time: DateTime(2024, 11, 18, 10, 30),
        status: ViolationStatus.resolved,
        severity: ViolationSeverity.low,
      ),
      ViolationModel(
        id: "V007",
        type: ViolationType.PPE,
        zone: "Zone D - Scaffolding",
        description: "Worker missing safety harness",
        time: DateTime(2024, 11, 17, 15, 45),
        status: ViolationStatus.resolved,
        severity: ViolationSeverity.high,
        imageUrl: "https://example.com/image1.jpg",
      ),
      ViolationModel(
        id: "V008",
        type: ViolationType.Unauthorized,
        zone: "Zone C - Storage Area",
        description: "Unauthorized entry attempt",
        time: DateTime(2024, 11, 17, 11, 20),
        status: ViolationStatus.acknowledged,
        severity: ViolationSeverity.medium,
        acknowledgedBy: "Site Manager",
      ),
    ];

    violations.assignAll(sampleData);
  }

  // Change from private to public methods by removing the underscore
  String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final violationDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (violationDay == today) {
      return 'Today';
    } else if (violationDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${_getMonthAbbr(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
    }
  }

  String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  List<ViolationModel> get filteredData {
    return violations.where((item) {
      final matchesSearch = item.description.toLowerCase().contains(searchTerm.value.toLowerCase()) ||
          item.zone.toLowerCase().contains(searchTerm.value.toLowerCase());
      final matchesFilter = filterType.value == null || item.type == filterType.value;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void setSearchTerm(String value) {
    searchTerm.value = value;
  }

  void setFilterType(ViolationType? type) {
    filterType.value = type;
  }

  void viewViolationDetails(ViolationModel violation) {
    print('🚀 Navigating to violation detail with: ${violation.id}');
    print('📤 Violation object: $violation');

    // Use direct navigation instead of named routes
    Get.to(
          () => const ViolationDetailView(),
      arguments: violation,
      binding: ViolationDetailBinding(),
    );
  }

  void exportData() {
    final exportData = filteredData.map((v) => {
      'ID': v.id,
      'Type': v.type.name,
      'Severity': v.severity.name,
      'Zone': v.zone,
      'Description': v.description,
      'Date': formatDate(v.time),
      'Time': formatTime(v.time),
      'Status': v.status.name,
      'Acknowledged By': v.acknowledgedBy ?? 'N/A',
    }).toList();

    // TODO: Implement actual CSV export
    Get.snackbar(
      'Export Successful',
      'Exporting ${filteredData.length} violation records to CSV...',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}