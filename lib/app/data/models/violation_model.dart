import '../../core/config/app_config.dart';

enum ViolationType { PPE, Unauthorized, Hazardous, Material }

enum ViolationSeverity { high, medium, low }

enum ViolationStatus { active, acknowledged, dismissed, resolved }

// ── Backend → Flutter enum mapping ──────────────────────────────────────────

ViolationType _typeFromBackend(String? raw) {
  switch (raw) {
    case 'no_helmet':
    case 'no_vest':
    case 'no_gloves':
    case 'no_boots':
    case 'no_mask':
      return ViolationType.PPE;
    case 'unauthorized_zone':
      return ViolationType.Unauthorized;
    case 'unsafe_material':
      return ViolationType.Material;
    default:
      return ViolationType.Hazardous;
  }
}

String _typeDescription(String? raw) {
  switch (raw) {
    case 'no_helmet':
      return 'No safety helmet detected';
    case 'no_vest':
      return 'No safety vest detected';
    case 'no_gloves':
      return 'No safety gloves detected';
    case 'no_boots':
      return 'No safety boots detected';
    case 'no_mask':
      return 'No face mask detected';
    case 'unauthorized_zone':
      return 'Unauthorized zone entry detected';
    case 'unsafe_material':
      return 'Unsafe material handling detected';
    default:
      return 'Safety violation detected';
  }
}

ViolationSeverity _severityFromBackend(String? raw) {
  switch (raw) {
    case 'high':
      return ViolationSeverity.high;
    case 'low':
      return ViolationSeverity.low;
    default:
      return ViolationSeverity.medium;
  }
}

ViolationStatus _statusFromBackend(String? raw) {
  switch (raw) {
    case 'acknowledged':
      return ViolationStatus.acknowledged;
    case 'resolved':
      return ViolationStatus.resolved;
    case 'false_positive':
      return ViolationStatus.dismissed;
    default:
      return ViolationStatus.active; // 'open'
  }
}

DateTime _parseDetectedAt(String? raw) {
  final parsed = DateTime.tryParse(raw ?? '');
  if (parsed == null) return DateTime.now();
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

// Safe integer parsing helper
int? _parseIntSafe(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

// Safe double parsing helper
double? _parseDoubleSafe(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

// ── Model ────────────────────────────────────────────────────────────────────

class ViolationModel {
  final String id;
  final ViolationType type;
  final String zone;
  final String description;
  final DateTime time;
  final ViolationStatus status;
  final ViolationSeverity severity;
  final String? imageUrl;
  final String? acknowledgedBy;
  final double? confidence;
  final int? cameraId;

  /// Raw backend type string (e.g. "no_helmet") for resolving
  final String? rawType;

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
    this.confidence,
    this.cameraId,
    this.rawType,
  });

  factory ViolationModel.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    final snapshotPath = json['snapshot_url'] as String?;
    final camera = json['camera'] as Map<String, dynamic>?;
    final cameraLocation = camera?['location'] as String? ?? camera?['name'] as String? ?? 'Unknown Zone';

    // Safe parsing for numeric values
    final confidenceValue = _parseDoubleSafe(json['confidence']);
    final cameraIdValue = _parseIntSafe(json['camera_id']);

    // Handle camera ID from nested camera object if present
    final cameraIdFromNested = camera?['id'] != null ? _parseIntSafe(camera?['id']) : null;

    final finalCameraId = cameraIdValue ?? cameraIdFromNested;

    return ViolationModel(
      id: json['id']?.toString() ?? '',
      type: _typeFromBackend(rawType),
      zone: cameraLocation,
      description: (json['notes'] as String?)?.isNotEmpty == true ? json['notes'] : _typeDescription(rawType),
      time: _parseDetectedAt(json['detected_at'] as String?),
      status: _statusFromBackend(json['status'] as String?),
      severity: _severityFromBackend(json['severity'] as String?),
      imageUrl: (() {
        if (snapshotPath == null) return null;
        final s = snapshotPath.trim();
        final lower = s.toLowerCase();
        if (lower.startsWith('http://') || lower.startsWith('https://')) return s;
        if (s.startsWith('/')) return '${AppConfig.imageBaseUrl}$s';
        return '${AppConfig.imageBaseUrl}/$s';
      })(),
      acknowledgedBy: json['resolved_by'] as String?,
      confidence: confidenceValue,
      cameraId: finalCameraId,
      rawType: rawType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': rawType ?? type.name,
    'zone': zone,
    'description': description,
    'time': time.toIso8601String(),
    'status': status.name,
    'severity': severity.name,
    'imageUrl': imageUrl,
    'acknowledgedBy': acknowledgedBy,
  };

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
    double? confidence,
    int? cameraId,
    String? rawType,
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
      confidence: confidence ?? this.confidence,
      cameraId: cameraId ?? this.cameraId,
      rawType: rawType ?? this.rawType,
    );
  }
}
