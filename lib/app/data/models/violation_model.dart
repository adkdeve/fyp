class ViolationModel {
  final String type;
  final String zone;
  final String description;
  final String time;
  final String status;
  final String severity;

  ViolationModel({
    required this.type,
    required this.zone,
    required this.description,
    required this.time,
    required this.status,
    required this.severity,
  });
}
