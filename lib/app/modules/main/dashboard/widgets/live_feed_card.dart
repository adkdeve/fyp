import 'package:construction_safety/app/modules/main/camera_feed/bindings/camera_feed_binding.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/models/camera_model.dart';
import '../../camera_feed/views/camera_feed_view.dart';

class LiveFeedCard extends StatelessWidget {
  final CameraModel camera;
  final String status; // safe, warning, critical
  final int openViolations;
  final String? violation;

  const LiveFeedCard({
    super.key,
    required this.camera,
    required this.status,
    required this.openViolations,
    this.violation,
  });

  @override
  Widget build(BuildContext context) {
    // Status colors
    final Map<String, dynamic> statusConfig = {
      "safe": {
        "bg": Colors.green.shade50,
        "border": Colors.green.shade200,
        "badgeBg": Colors.green.shade100,
        "badgeText": Colors.green.shade700,
        "text": "Clear",
        "icon": LucideIcons.circleCheck,
      },
      "warning": {
        "bg": Colors.yellow.shade50,
        "border": Colors.yellow.shade200,
        "badgeBg": Colors.yellow.shade100,
        "badgeText": Colors.yellow.shade700,
        "text": "Warning",
        "icon": LucideIcons.triangleAlert,
      },
      "critical": {
        "bg": Colors.red.shade50,
        "border": Colors.red.shade200,
        "badgeBg": Colors.red.shade100,
        "badgeText": Colors.red.shade700,
        "text": "Critical",
        "icon": LucideIcons.circleAlert,
      },
    };

    final config = statusConfig[status]!;

    return GestureDetector(
      onTap: () => Get.to(
        () => const CameraFeedView(),
        arguments: camera,
        binding: CameraFeedBinding(),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: config["bg"],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: config["border"]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Zone + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.video, size: 18),
                    const SizedBox(width: 5),
                    Text(camera.zone),
                  ],
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: config["badgeBg"],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(config["icon"], size: 14, color: config["badgeText"]),
                      const SizedBox(width: 4),
                      Text(
                        config["text"],
                        style: TextStyle(
                          color: config["badgeText"],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Camera ID + Worker count + Violation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Camera #${camera.id}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Text(
                  "${camera.fpsTarget} FPS target",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  camera.enabled ? 'Monitoring enabled' : 'Monitoring disabled',
                  style: TextStyle(
                    fontSize: 12,
                    color: camera.enabled
                        ? Colors.green.shade700
                        : Colors.grey.shade700,
                  ),
                ),
                Text(
                  '$openViolations open violation${openViolations == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            if (violation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  violation!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      camera.enabled
                          ? 'Tap to open the live feed for this camera.'
                          : 'Enable this camera in Camera Management to monitor it.',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
