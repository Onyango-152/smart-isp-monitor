import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/report_model.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final report = ModalRoute.of(context)?.settings.arguments;
    if (report == null || report is! ReportModel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Detail')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'No Report Data',
          message: 'No report was passed to this screen.',
          color: AppColors.offline,
        ),
      );
    }
    return _DetailContent(report: report);
  }
}

class _DetailContent extends StatelessWidget {
  final ReportModel report;
  const _DetailContent({required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildKpiRow()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Device Status',
              icon: Icons.devices_rounded,
            ),
          ),
          SliverToBoxAdapter(child: _buildDeviceDistribution()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Alert Breakdown',
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.degraded,
            ),
          ),
          SliverToBoxAdapter(child: _buildAlertBreakdown()),
          if (report.dailyLatency != null &&
              report.dailyLatency!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Latency Trend',
                icon: Icons.show_chart_rounded,
              ),
            ),
            SliverToBoxAdapter(child: _buildLatencyChart()),
          ],
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Report Details',
              icon: Icons.info_outline_rounded,
            ),
          ),
          SliverToBoxAdapter(child: _buildDetailsCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(BuildContext context) {
    final typeLabel = switch (report.type) {
      'daily' => 'Daily Report',
      'weekly' => 'Weekly Report',
      'monthly' => 'Monthly Report',
      _ => 'Report',
    };
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.appBarGradientStart,
                AppColors.appBarGradientEnd,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$typeLabel  •  ${AppUtils.formatShortDate(report.periodStart)} — ${AppUtils.formatShortDate(report.periodEnd)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── KPI Row ───────────────────────────────────────────────────────────────

  Widget _buildKpiRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _kpi('Uptime', '${report.uptimePct.toStringAsFixed(1)}%',
              AppColors.online),
          const SizedBox(width: 10),
          _kpi('Avg Latency', '${report.avgLatencyMs.toStringAsFixed(1)} ms',
              AppUtils.latencyColor(report.avgLatencyMs)),
          const SizedBox(width: 10),
          _kpi('MTTR', '${report.avgMttrMinutes.toStringAsFixed(0)} min',
              AppColors.primary),
          const SizedBox(width: 10),
          _kpi('Faults', '${report.totalFaults}', AppColors.offline),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  // ── Device Distribution ───────────────────────────────────────────────────

  Widget _buildDeviceDistribution() {
    final total = report.totalDevices;
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // ── Donut chart ──────────────────────────────────────────
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: AppColors.online,
                      value: report.onlineDevices.toDouble(),
                      title: '${report.onlineDevices}',
                      titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      radius: 30,
                    ),
                    if (report.degradedDevices > 0)
                      PieChartSectionData(
                        color: AppColors.degraded,
                        value: report.degradedDevices.toDouble(),
                        title: '${report.degradedDevices}',
                        titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        radius: 30,
                      ),
                    if (report.offlineDevices > 0)
                      PieChartSectionData(
                        color: AppColors.offline,
                        value: report.offlineDevices.toDouble(),
                        title: '${report.offlineDevices}',
                        titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        radius: 30,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendDot(AppColors.online, 'Online (${report.onlineDevices})'),
                _legendDot(
                    AppColors.degraded, 'Degraded (${report.degradedDevices})'),
                _legendDot(
                    AppColors.offline, 'Offline (${report.offlineDevices})'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  // ── Alert Breakdown ───────────────────────────────────────────────────────

  Widget _buildAlertBreakdown() {
    final data = report.alertsBySeverity;
    if (data == null || data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.card,
          ),
          child: const Center(
            child: Text('No alert data', style: TextStyle(color: AppColors.textHint)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // ── Resolution rate ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Resolution Rate', style: AppTextStyles.labelBold),
                Text(
                  '${report.resolutionRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: report.resolutionRate >= 80
                        ? AppColors.online
                        : report.resolutionRate >= 50
                            ? AppColors.degraded
                            : AppColors.offline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: report.resolutionRate / 100,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(
                  report.resolutionRate >= 80
                      ? AppColors.online
                      : report.resolutionRate >= 50
                          ? AppColors.degraded
                          : AppColors.offline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Severity bars ────────────────────────────────────────
            ...data.map((item) {
              final sev = item['severity'] as String;
              final count = item['count'] as int;
              final color = AppUtils.severityColor(sev);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        AppUtils.severityLabel(sev),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$count',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Latency Chart ─────────────────────────────────────────────────────────

  Widget _buildLatencyChart() {
    final data = report.dailyLatency!;
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
    }).toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: (maxY * 1.2).ceilToDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY / 4).clamp(10, 200),
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.divider,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: report.type == 'daily'
                        ? 6
                        : report.type == 'weekly'
                            ? 1
                            : 7,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        data[idx].values.first.toString(),
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textHint),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} ms',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Details Card ──────────────────────────────────────────────────────────

  Widget _buildDetailsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            InfoRow(label: 'Report Type', value: report.type.toUpperCase()),
            InfoRow(label: 'Status', value: report.status.toUpperCase()),
            InfoRow(
                label: 'Period Start',
                value: AppUtils.formatDateTime(report.periodStart)),
            InfoRow(
                label: 'Period End',
                value: AppUtils.formatDateTime(report.periodEnd)),
            InfoRow(
                label: 'Generated',
                value: AppUtils.formatDateTime(report.generatedAt)),
            InfoRow(
                label: 'Total Devices',
                value: '${report.totalDevices}'),
            InfoRow(
                label: 'Total Alerts',
                value: '${report.totalAlerts}'),
            InfoRow(
                label: 'Resolved Alerts',
                value: '${report.resolvedAlerts}'),
            InfoRow(
                label: 'Total Faults',
                value: '${report.totalFaults}'),
          ],
        ),
      ),
    );
  }
}
