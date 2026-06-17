import 'package:construction_safety/app/modules/main/camera_feed/bindings/camera_feed_binding.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';

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
    // Status accent (theme-aware: light tint in light mode, dark tint in dark mode)
    final Color base = status == 'safe'
        ? Colors.green
        : status == 'warning'
            ? Colors.amber
            : Colors.red;
    final Map<String, dynamic> config = {
      "bg": AppColor.tintedSurface(base),
      "border": AppColor.accentBorder(base),
      "badgeBg": AppColor.accentBadgeBg(base),
      "badgeText": AppColor.accentText(base),
      "text": status == 'safe'
          ? 'Clear'
          : status == 'warning'
              ? 'Warning'
              : 'Critical',
      "icon": status == 'safe'
          ? LucideIcons.circleCheck
          : status == 'warning'
              ? LucideIcons.triangleAlert
              : LucideIcons.circleAlert,
    };

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
                    Icon(LucideIcons.video, size: 18, color: AppColor.textPrimary),
                    const SizedBox(width: 5),
                    Text(
                      camera.zone,
                      style: TextStyle(color: AppColor.textPrimary, fontWeight: FontWeight.w600),
                    ),
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
                  style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
                ),
                Text(
                  "${camera.fpsTarget} FPS target",
                  style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
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
                        ? AppColor.accentText(Colors.green)
                        : AppColor.textSecondary,
                  ),
                ),
                Text(
                  '$openViolations open violation${openViolations == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
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
                color: AppColor.subtleBg,
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
                        color: AppColor.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: AppColor.textSecondary,
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
