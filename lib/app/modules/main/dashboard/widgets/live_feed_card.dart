import 'package:construction_safety/app/modules/main/camera_feed/bindings/camera_feed_binding.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/models/camera_model.dart';
import '../../camera_feed/views/camera_feed_view.dart';

class LiveFeedCard extends StatelessWidget {
  final CameraModel camera;
  final String zone;
  final String status; // safe, warning, critical
  final int workers;
  final String? violation;

  const LiveFeedCard({
    super.key,
    required this.camera,
    required this.zone,
    required this.status,
    required this.workers,
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
        "text": "Safe",
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
        arguments: violation,
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
                    Text(zone),
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
                Text("${camera.id}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Row(
                  children: [
                    const Icon(LucideIcons.users, size: 14),
                    const SizedBox(width: 2),
                    Text("$workers workers", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            if (violation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  violation!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 8),
            // Video Feed Placeholder
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                    ),
                    itemCount: 48,
                    itemBuilder: (context, index) => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                  ),
                ),
                // LIVE Badge
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "LIVE",
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                // Timestamp
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Text(
                    "${TimeOfDay.fromDateTime(DateTime.now()).format(context)}",
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
