import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

import '../controllers/analytics_controller.dart';

class AnalyticsView extends GetView<AnalyticsController> {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.white,
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              // Header
              _buildHeader(),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Key Metrics
                      _buildKeyMetrics(),
                      const SizedBox(height: 16),
                      // Weekly Violations Chart
                      _buildViolationsChart(),
                      const SizedBox(height: 16),
                      // Violation Types Distribution
                      _buildViolationTypesChart(),
                      const SizedBox(height: 16),
                      // Compliance Trend
                      _buildComplianceTrend(),
                      const SizedBox(height: 16),
                      // Zone Performance
                      _buildZonePerformance(context), // Pass context here
                      const SizedBox(height: 16),
                      // AI Detection Performance
                      _buildAIDetectionPerformance(
                        context,
                      ), // Pass context here
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

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Title and Export Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety Analytics',
                    style: Get.textTheme.titleLarge?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Performance insights and trends',
                    style: Get.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: controller.handleExport,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.download_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Time Range Filter
          _buildTimeRangeFilter(),
        ],
      ),
    );
  }

  Widget _buildTimeRangeFilter() {
    return Row(
      children: [
        _buildTimeRangeButton('Week', 'week'),
        const SizedBox(width: 8),
        _buildTimeRangeButton('Month', 'month'),
        const SizedBox(width: 8),
        _buildTimeRangeButton('Year', 'year'),
      ],
    );
  }

  Widget _buildTimeRangeButton(String label, String value) {
    return Expanded(
      child: Obx(() {
        final isSelected = controller.timeRange.value == value;
        return ElevatedButton(
          onPressed: () => controller.setTimeRange(value),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue[100] : Colors.grey[100],
            foregroundColor: isSelected ? Colors.blue[700] : Colors.grey[600],
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, size: 14),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildKeyMetrics() {
    return Obx(
      () => GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        children: [
          _buildMetricCard(
            'Compliance Rate',
            '${controller.complianceRate.value}%',
            '+5% from last week',
            Colors.green,
            Icons.trending_up,
            () => controller.showMetricDetails('compliance'),
          ),
          _buildMetricCard(
            'Total Violations',
            '${controller.totalViolations.value}',
            '-12% from last week',
            Colors.red,
            Icons.trending_down,
            () => controller.showMetricDetails('violations'),
          ),
          _buildMetricCard(
            'Avg Response Time',
            '${controller.avgResponseTime.value.toStringAsFixed(1)}s',
            'Detection to alert',
            Colors.blue,
            Icons.bar_chart,
            () => controller.showMetricDetails('response'),
          ),
          _buildMetricCard(
            'Active Zones',
            '${controller.activeZones.value}',
            'All zones monitored',
            Colors.purple,
            Icons.warning_amber,
            () => controller.showMetricDetails('zones'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(icon, color: Colors.white, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViolationsChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Obx(
                () => Text(
                  '${controller.timeRange.value == "week"
                      ? "Weekly"
                      : controller.timeRange.value == "month"
                      ? "Monthly"
                      : "Yearly"} Violations',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.bar_chart, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final data = controller.currentData;
                          if (value.toInt() < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                data[value.toInt()].period,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: controller.currentData
                      .asMap()
                      .entries
                      .map(
                        (entry) => BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.violations.toDouble(),
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                              width: 16,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationTypesChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Violation Types',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Icon(Icons.pie_chart, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: controller.violationTypeData
                      .map(
                        (data) => PieChartSectionData(
                          value: data.value.toDouble(),
                          color: data.color,
                          radius: 40,
                          title: '${data.value}%',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                      .toList(),
                  centerSpaceRadius: 50,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3,
              ),
              itemCount: controller.violationTypeData.length,
              itemBuilder: (context, index) {
                final data = controller.violationTypeData[index];
                return GestureDetector(
                  onTap: () => controller.showViolationTypeDetails(data),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: data.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${data.name} (${data.value}%)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceTrend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compliance Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Icon(Icons.trending_up, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() <
                              controller.complianceTrend.length) {
                            return Text(
                              controller.complianceTrend[value.toInt()].week,
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: controller.complianceTrend
                          .asMap()
                          .entries
                          .map(
                            (entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value.compliance.toDouble(),
                            ),
                          )
                          .toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 4,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated to accept BuildContext parameter
  Widget _buildZonePerformance(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width - 64; // Calculate available width

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          const Text(
            'Zone Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => Column(
              children: controller.zonePerformance.map((zone) {
                return GestureDetector(
                  onTap: () => controller.showZoneDetails(zone),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                zone.zone,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${zone.compliance}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Container(
                                width: screenWidth * (zone.compliance / 100),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: zone.compliance >= 90
                                      ? Colors.green
                                      : zone.compliance >= 80
                                      ? Colors.yellow[700]!
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${zone.violations} violations this week',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Updated to accept BuildContext parameter
  Widget _buildAIDetectionPerformance(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width - 64; // Calculate available width

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          const Text(
            'AI Detection Performance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => _buildAIMetric(
              'Detection Accuracy',
              '${controller.detectionAccuracy.value}%',
              controller.detectionAccuracy.value / 100,
              Colors.blue,
              screenWidth,
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => _buildAIMetric(
              'False Positive Rate',
              '${controller.falsePositiveRate.value.toStringAsFixed(1)}%',
              controller.falsePositiveRate.value / 100,
              Colors.orange,
              screenWidth,
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => _buildAIMetric(
              'Processing Speed',
              '${controller.processingFps.value} FPS',
              1.0,
              Colors.green,
              screenWidth,
            ),
          ),
        ],
      ),
    );
  }

  // Updated to accept screenWidth parameter
  Widget _buildAIMetric(
    String label,
    String value,
    double percentage,
    Color color,
    double screenWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              Container(
                width: screenWidth * percentage,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
