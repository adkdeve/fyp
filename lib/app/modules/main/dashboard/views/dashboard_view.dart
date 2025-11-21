import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/live_feed_card.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Obx(() {
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildStatsSection(),
              _buildStatusCards(),
              _buildRecentAlert(),
              _buildLiveFeeds(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Construction Safety Monitor",
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 5),
          Text(
            "${DateFormat.yMMMMd().format(controller.currentTime.value)} • ${DateFormat.jm().format(controller.currentTime.value)}",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(LucideIcons.video, "Live Feeds",
              controller.cameras.where((c) => c.status == "online").length),
          _buildStatCard(LucideIcons.users, "Workers", controller.totalWorkers),
          _buildStatCard(LucideIcons.circleCheck, "Safe", controller.safeWorkers),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, int value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.blue[600]),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text("$value", style: const TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatus("Compliant", controller.complianceRate, Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatus("Violations", controller.activeViolations.length, Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text("$value",
              style: const TextStyle(fontSize: 22, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildRecentAlert() {
    if (controller.activeViolations.isEmpty) return const SizedBox();

    final v = controller.activeViolations.first;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(left: BorderSide(color: Colors.red.shade400, width: 4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, color: Colors.red.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${v.type} Violation Detected",
                    style: TextStyle(color: Colors.red.shade800)),
                Text("${v.zone} - ${v.description}",
                    style: TextStyle(color: Colors.red.shade600)),
                Text(v.time, style: TextStyle(fontSize: 12, color: Colors.red.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveFeeds() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Live Camera Feeds", style: TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          ...controller.cameras.map((camera) {
            return LiveFeedCard(camera: camera);
          }).toList(),
        ],
      ),
    );
  }
}
