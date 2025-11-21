import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/models/camera_model.dart';
import '../../camera_feed/views/camera_feed_view.dart';

class LiveFeedCard extends StatelessWidget {
  final CameraModel camera;
  const LiveFeedCard({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    final isOffline = camera.status == "offline";

    return GestureDetector(
      onTap: () => Get.to(() => CameraFeedView(camera: camera)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOffline ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOffline ? Colors.red.shade200 : Colors.green.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.video, size: 18),
                    const SizedBox(width: 5),
                    Text(camera.zone),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOffline ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOffline ? "Critical" : "Safe",
                    style: TextStyle(
                      color: isOffline ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 120,
              color: Colors.black,
              child: const Center(
                child: Text("Live Feed Placeholder",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
