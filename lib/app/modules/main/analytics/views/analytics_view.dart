import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:construction_safety/app/core/extensions/theme_extensions.dart';
import 'package:construction_safety/common/widgets/app_header.dart';

import '../controllers/analytics_controller.dart';

class AnalyticsView extends GetView<AnalyticsController> {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColor.statusBar,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: AppColor.scaffoldBg,
          body: Column(
            children: [
              AppHeader(
                title: 'Safety Analytics',
                subtitle: 'Performance insights and trends',
                actions: [
                  OutlinedButton.icon(
                    onPressed: controller.handleExport,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColor.textPrimary,
                      side: BorderSide(color: AppColor.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
                bottom: _buildTimeRangeFilter(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMetricCards(),
                      const SizedBox(height: 16),
                      _buildComplianceCard(),
                      const SizedBox(height: 16),
                      _buildViolationsOverTime(),
                      const SizedBox(height: 16),
                      _buildViolationTypes(),
                      const SizedBox(height: 16),
                      _buildCamerasByViolations(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColor.subtleBg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        children: [
          _rangeButton('Week', 'week'),
          _rangeButton('Month', 'month'),
          _rangeButton('Year', 'year'),
        ],
      ),
    );
  }

  Widget _rangeButton(String label, String value) {
    return Expanded(
      child: Obx(() {
        final selected = controller.timeRange.value == value;
        return GestureDetector(
          onTap: () => controller.setTimeRange(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF4F46E5) : Colors.transparent,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColor.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Metric cards ─────────────────────────────────────────────────────────────
  Widget _buildMetricCards() {
    return Obx(
      () => GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
        ),
        children: [
          _metricCard('Total Violations', '${controller.totalViolations}', Icons.warning_amber_rounded,
              const [Color(0xFFF43F5E), Color(0xFFEC4899)]),
          _metricCard('High Priority', '${controller.highCount}', Icons.shield_outlined,
              const [Color(0xFFEF4444), Color(0xFFE11D48)]),
          _metricCard('Resolved', '${controller.resolvedCount}', Icons.check_circle_outline,
              const [Color(0xFF10B981), Color(0xFF14B8A6)]),
          _metricCard('Active Cameras', '${controller.activeCameras}', Icons.videocam_outlined,
              const [Color(0xFF0EA5E9), Color(0xFF2563EB)]),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: gradient.last.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Compliance rate ──────────────────────────────────────────────────────────
  Widget _buildComplianceCard() {
    return _card(
      child: Obx(() {
        final pct = controller.compliancePct;
        final color = pct >= 80
            ? const Color(0xFF10B981)
            : pct >= 60
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);
        return Row(
          children: [
            SizedBox(
              height: 88,
              width: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 88,
                    width: 88,
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 8,
                      valueColor: AlwaysStoppedAnimation(AppColor.borderColor),
                    ),
                  ),
                  SizedBox(
                    height: 88,
                    width: 88,
                    child: CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Text('$pct%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColor.textPrimary)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Compliance Rate',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Based on ${controller.totalViolations} detection(s) in this period',
                      style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _sevPill('${controller.highCount} high', const Color(0xFFF43F5E)),
                      const SizedBox(width: 12),
                      _sevPill('${controller.mediumCount} medium', const Color(0xFFF59E0B)),
                      const SizedBox(width: 12),
                      _sevPill('${controller.lowCount} low', const Color(0xFF3B82F6)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _sevPill(String text, Color color) {
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color));
  }

  // ── Violations over time (bar chart) ─────────────────────────────────────────
  Widget _buildViolationsOverTime() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Violations Over Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
              Obx(() => Text(controller.timeRange.value.toUpperCase(),
                  style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: AppColor.textSecondary))),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final data = controller.timeSeries;
            if (data.isEmpty) {
              return SizedBox(
                height: 180,
                child: Center(
                  child: Text('No violations in this period', style: TextStyle(color: AppColor.textSecondary, fontSize: 13)),
                ),
              );
            }
            final maxY = data.map((e) => e.count).fold<int>(1, (a, b) => b > a ? b : a).toDouble();
            return SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY + (maxY * 0.2),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        '${data[group.x].label}\n${rod.toY.toInt()}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) =>
                            Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= data.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(data[i].label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data
                      .asMap()
                      .entries
                      .map((e) => BarChartGroupData(x: e.key, barRods: [
                            BarChartRodData(
                              toY: e.value.count.toDouble(),
                              color: const Color(0xFF6366F1),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ]))
                      .toList(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Violation types ──────────────────────────────────────────────────────────
  Widget _buildViolationTypes() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Violation Types',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
          const SizedBox(height: 16),
          Obx(() {
            final types = controller.typeBreakdown;
            final total = controller.totalViolations;
            if (types.isEmpty) {
              return Text('No data', style: TextStyle(color: AppColor.textSecondary, fontSize: 13));
            }
            return Column(
              children: types.map((t) {
                final pct = total == 0 ? 0 : ((t.count / total) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('${t.count} ($pct%)', style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 8,
                          backgroundColor: AppColor.subtleBg,
                          valueColor: AlwaysStoppedAnimation(t.color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // ── Cameras by violations ────────────────────────────────────────────────────
  Widget _buildCamerasByViolations() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cameras by Violations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
          const SizedBox(height: 16),
          Obx(() {
            final cams = controller.topCameras;
            if (cams.isEmpty) {
              return Text('No violations in this period', style: TextStyle(color: AppColor.textSecondary, fontSize: 13));
            }
            final max = cams.first.count == 0 ? 1 : cams.first.count;
            return Column(
              children: cams.map((c) {
                final pct = c.count / max;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(c.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9999),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 10,
                            backgroundColor: AppColor.subtleBg,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text('${c.count}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  // ── Shared card wrapper ──────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: child,
    );
  }
}
