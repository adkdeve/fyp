enum CameraStatus { online, offline }

class CameraModel {
  final String id;
  final String zone;
  final String status;

  CameraModel({
    required this.id,
    required this.zone,
    required this.status,
  });

  // Add these properties for the camera management screen
  String get name => "Camera $id"; // Generate name from ID
  bool get recording => false; // Default recording status
  CameraStatus get cameraStatus =>
      status.toLowerCase() == "online" ? CameraStatus.online : CameraStatus.offline;

  CameraModel copyWith({
    String? id,
    String? zone,
    String? status,
  }) {
    return CameraModel(
      id: id ?? this.id,
      zone: zone ?? this.zone,
      status: status ?? this.status,
    );
  }
}