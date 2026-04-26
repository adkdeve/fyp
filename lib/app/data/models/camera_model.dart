enum CameraStatus { online, offline, error }

class CameraModel {
  final int id;
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

  bool get recording => false; // cameras stream continuously; no separate recording toggle

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: json['id'] as int,
      name: json['name'] as String,
      rtspUrl: json['rtsp_url'] as String,
      location: json['location'] as String?,
      siteName: json['site_name'] as String?,
      status: (json['status'] as String?) ?? 'offline',
      enabled: (json['enabled'] as bool?) ?? false,
      fpsTarget: (json['fps_target'] as int?) ?? 5,
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
