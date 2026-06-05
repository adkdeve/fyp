enum CameraStatus { online, offline, error }

class CameraModel {
  final dynamic id; // supports both int and String (Firebase IDs)
  final String name;
  final String rtspUrl;
  final String? location;
  final String? siteName;
  final String status;
  final bool enabled;
  final int fpsTarget;

  CameraModel({
    required this.id,
    required this.name,
    required this.rtspUrl,
    this.location,
    this.siteName,
    required this.status,
    required this.enabled,
    this.fpsTarget = 5,
  });

  /// Backward-compat getter used in older widgets
  String get zone => location ?? siteName ?? name;

  CameraStatus get cameraStatus {
    switch (status.toLowerCase()) {
      case 'online':
        return CameraStatus.online;
      case 'error':
        return CameraStatus.error;
      default:
        return CameraStatus.offline;
    }
  }

  bool get recording =>
      false; // cameras stream continuously; no separate recording toggle

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    final site = json['site'] as Map<String, dynamic>?;
    final rawId = json['id'];
    final rawEnabled = json['enabled'];
    final rawFpsTarget = json['fps_target'];
    final rawStatus = json['status']?.toString();

    return CameraModel(
      id: rawId, // Keep original ID (String for Firebase, int for backend)
      name: json['name']?.toString() ?? site?['name']?.toString() ?? 'Camera',
      rtspUrl:
          json['rtsp_url']?.toString() ?? json['stream_url']?.toString() ?? '',
      location: json['location']?.toString() ?? site?['address']?.toString(),
      siteName: json['site_name']?.toString() ?? site?['name']?.toString(),
      status: rawStatus == null || rawStatus.isEmpty
          ? 'offline'
          : rawStatus.split('.').last.toLowerCase(),
      enabled: rawEnabled is bool
          ? rawEnabled
          : rawEnabled is num
          ? rawEnabled != 0
          : rawEnabled?.toString().toLowerCase() == 'true',
      fpsTarget: rawFpsTarget is int
          ? rawFpsTarget
          : rawFpsTarget is num
          ? rawFpsTarget.toInt()
          : int.tryParse('${rawFpsTarget ?? ''}') ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rtsp_url': rtspUrl,
    'location': location,
    'site_name': siteName,
    'status': status,
    'enabled': enabled,
    'fps_target': fpsTarget,
  };

  CameraModel copyWith({
    int? id,
    String? name,
    String? rtspUrl,
    String? location,
    String? siteName,
    String? status,
    bool? enabled,
    int? fpsTarget,
  }) {
    return CameraModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      location: location ?? this.location,
      siteName: siteName ?? this.siteName,
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      fpsTarget: fpsTarget ?? this.fpsTarget,
    );
  }
}
