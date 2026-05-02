import 'package:construction_safety/app/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/models/violation_model.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/live_feed_card.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final overlayStyle = SystemUiOverlayStyle.light.copyWith(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.blue.shade700,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Obx(
          () => SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatusCards(),
                ),
                if (controller.mostRecentViolation != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border(
                        left: BorderSide(
                          color: Colors.red.shade500,
                          width: 4,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red.shade500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${controller.mostRecentViolation!.type} Violation Detected",
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "${controller.mostRecentViolation!.zone} - ${controller.mostRecentViolation!.description}",
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'hh:mm a',
                                ).format(controller.mostRecentViolation!.time),
                                style: TextStyle(
                                  color: Colors.red.shade500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.video, size: 18),
                          5.sbw,
                          const Text(
                            "Monitored Cameras",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (controller.cameras.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No enabled cameras are being monitored right now.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        )
                      else
                        Column(
                          children: controller.cameras.map((camera) {
                            final activeViolations = controller.violations
                                .where(
                                  (v) =>
                                      v.cameraId == camera.id &&
                                      v.status == ViolationStatus.active,
                                )
                                .toList();
                            final hasViolation = activeViolations.isNotEmpty;
                            final violation = hasViolation
                                ? activeViolations.first
                                : null;
                            final status = camera.status != "online"
                                ? "critical"
                                : hasViolation
                                ? (violation!.severity == ViolationSeverity.high
                                      ? "critical"
                                      : "warning")
                                : "safe";

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: LiveFeedCard(
                                camera: camera,
                                status: status,
                                violation: violation?.description,
                                openViolations: activeViolations.length,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Construction Safety Monitor",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${controller.currentTime.value.toLocal().toString().split(' ')[0]} • ${TimeOfDay.fromDateTime(controller.currentTime.value).format(context)}",
                      style: TextStyle(
                        color: Colors.blue.shade100,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.engineering, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _quickStat(
                  icon: Icons.videocam,
                  label: "Enabled",
                  value: controller.enabledCameraCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickStat(
                  icon: Icons.wifi_tethering,
                  label: "Online",
                  value: controller.onlineCameraCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickStat(
                  icon: Icons.check_circle,
                  label: "Compliant",
                  value: controller.compliantCameras.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        if (compact) {
          return Column(
            children: [
              _statusCard(
                label: "Safety Coverage",
                value: "${controller.complianceRate}%",
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _statusCard(
                label: "Open Violations",
                value: "${controller.activeViolationsCount}",
                icon: Icons.warning,
                color: Colors.red,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _statusCard(
                label: "Safety Coverage",
                value: "${controller.complianceRate}%",
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statusCard(
                label: "Open Violations",
                value: "${controller.activeViolationsCount}",
                icon: Icons.warning,
                color: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _quickStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
