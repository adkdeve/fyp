enum ViolationType { PPE, Unauthorized, Hazardous, Material }
enum ViolationSeverity { high, medium, low }
enum ViolationStatus { active, acknowledged, dismissed, resolved }

class ViolationModel {
  final String id;
  final ViolationType type;
  final String zone;
  final String description;
  final DateTime time;
  final ViolationStatus status;
  final ViolationSeverity severity;
  final String? imageUrl;         // Optional: image from detection
  final String? acknowledgedBy;   // Optional: worker/site manager

  ViolationModel({
    required this.id,
    required this.type,
    required this.zone,
    required this.description,
    required this.time,
    required this.status,
    required this.severity,
    this.imageUrl,
    this.acknowledgedBy,
  });

  // Convert model to JSON (API/Post)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'zone': zone,
      'description': description,
      'time': time.toIso8601String(),
      'status': status.name,
      'severity': severity.name,
      'imageUrl': imageUrl,
      'acknowledgedBy': acknowledgedBy,
    };
  }

  // Convert JSON to Model (API/Get)
  factory ViolationModel.fromJson(Map<String, dynamic> json) {
    return ViolationModel(
      id: json['id'] ?? '',
      type: ViolationType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => ViolationType.PPE,
      ),
      zone: json['zone'] ?? '',
      description: json['description'] ?? '',
      time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      status: ViolationStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => ViolationStatus.active,
      ),
      severity: ViolationSeverity.values.firstWhere(
            (e) => e.name == json['severity'],
        orElse: () => ViolationSeverity.medium,
      ),
      imageUrl: json['imageUrl'],
      acknowledgedBy: json['acknowledgedBy'],
    );
  }

  // For updating fields immutably
  ViolationModel copyWith({
    String? id,
    ViolationType? type,
    String? zone,
    String? description,
    DateTime? time,
    ViolationStatus? status,
    ViolationSeverity? severity,
    String? imageUrl,
    String? acknowledgedBy,
  }) {
    return ViolationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      zone: zone ?? this.zone,
      description: description ?? this.description,
      time: time ?? this.time,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      imageUrl: imageUrl ?? this.imageUrl,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }
}
