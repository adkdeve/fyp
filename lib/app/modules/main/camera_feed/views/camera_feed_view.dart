import 'package:flutter/material.dart';
import '../../../../data/models/camera_model.dart';

class CameraFeedView extends StatelessWidget {
  final CameraModel? camera; // ← Nullable now

  const CameraFeedView({super.key, this.camera});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(camera?.zone ?? "No Camera Selected"), // ← Fallback
      ),
      body: Center(
        child: Text(
          camera != null
              ? "Camera Live Feed - ${camera!.id}"
              : "No camera data available", // ← Conditional display
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
