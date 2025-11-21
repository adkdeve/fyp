import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/live_feed_card.dart';

class DashboardView extends StatelessWidget {
  final DashboardController controller = Get.put(DashboardController());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Obx(
              () => SingleChildScrollView(
            child: Column(
              children: [
                // HEADER + BLUE BACKGROUND
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 280,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER ROW
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Construction Safety Monitor",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${controller.currentTime.value.toLocal().toString().split(' ')[0]} • ${TimeOfDay.fromDateTime(controller.currentTime.value).format(context)}",
                                    style: TextStyle(
                                        color: Colors.blue.shade100,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.engineering,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // QUICK STATS ROW
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _quickStat(
                                icon: Icons.videocam,
                                label: "Live Feeds",
                                value: controller.cameras
                                    .where((c) => c.status == 'online')
                                    .length
                                    .toString(),
                              ),
                              _quickStat(
                                icon: Icons.people,
                                label: "Workers",
                                value: controller.totalWorkers.toString(),
                              ),
                              _quickStat(
                                icon: Icons.check_circle,
                                label: "Safe",
                                value: controller.safeWorkers.toString(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // COMPLIANT & VIOLATION CARDS overlapping header
                    Positioned(
                      bottom: -40,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statusCard(
                            label: "Compliant",
                            value: "${controller.complianceRate}%",
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                          _statusCard(
                            label: "Violations",
                            value: "${controller.activeViolationsCount}",
                            icon: Icons.warning,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                // MOST RECENT ALERT
                if (controller.mostRecentViolation != null)
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border(
                        left:
                        BorderSide(color: Colors.red.shade500, width: 4),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                controller.mostRecentViolation!.time,
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
                const SizedBox(height: 16),
                // LIVE CAMERA FEEDS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Live Camera Feeds",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: controller.cameras.map((camera) {
                          final activeViolations = controller.violations
                              .where((v) =>
                          v.zone
                              .contains(camera.zone.split(" - ")[0]) &&
                              v.status == 'active')
                              .toList();
                          final hasViolation = activeViolations.isNotEmpty;
                          final violation =
                          hasViolation ? activeViolations[0] : null;
                          String status = camera.status == "offline"
                              ? "critical"
                              : hasViolation
                              ? (violation!.severity == "high"
                              ? "critical"
                              : "warning")
                              : "safe";

                          return LiveFeedCard(
                            camera: camera,
                            zone: camera.zone,
                            status: status,
                            workers: (3 + (camera.id.hashCode % 10)),
                            violation: violation?.description,
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

  // Quick stats widget inside header
  Widget _quickStat(
      {required IconData icon, required String label, required String value}) =>
      Container(
        width: (Get.width - 64) / 3,
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
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // Status cards widget (Compliant / Violations)
  Widget _statusCard(
      {required String label,
        required String value,
        required IconData icon,
        required Color color}) =>
      Container(
        width: (Get.width - 48) / 2,
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
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900)),
            const SizedBox(height: 4),
            const Text("Safety Score",
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );
}
