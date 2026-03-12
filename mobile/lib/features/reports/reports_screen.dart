import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/report_model.dart';
import 'reports_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: provider.isLoading
              ? _buildLoading()
              : provider.errorMessage != null
                  ? _buildError(provider)
                  : _buildContent(context, provider),
        );
      },
    );
  }

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverFillRemaining(child: ShimmerSkeleton.deviceList()),
      ],
    );
  }

  Widget _buildError(ReportsProvider provider) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverFillRemaining(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Failed to Load Reports',
            message: provider.errorMessage!,
            color: AppColors.offline,
            actionLabel: 'Retry',
            onAction: provider.refresh,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ReportsProvider provider) {
    final latest = provider.latestCompleted;
    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(),

          // ── KPI Overview ────────────────────────────────────────────
          if (latest != null) ...[
            SliverToBoxAdapter(child: _KpiStrip(report: latest)),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Network Health',
                subtitle: 'Latest report overview',
                icon: Icons.monitor_heart_rounded,
              ),
            ),
            SliverToBoxAdapter(child: _DeviceStatusBar(report: latest)),
            SliverToBoxAdapter(child: _AlertSeverityChart(report: latest)),
            if (latest.dailyLatency != null && latest.dailyLatency!.isNotEmpty)
              SliverToBoxAdapter(child: _LatencyChart(report: latest)),
          ],

          // ── Filter chips ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Generated Reports',
              subtitle: '${provider.reports.length} reports',
              icon: Icons.description_rounded,
            ),
          ),
          SliverToBoxAdapter(child: _FilterChips(provider: provider)),

          // ── Reports list ────────────────────────────────────────────
          if (provider.reports.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.description_outlined,
                title: 'No Reports',
                message: 'No reports match the current filter.',
                color: AppColors.textHint,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: provider.reports.length,
                itemBuilder: (context, i) =>
                    _ReportTile(report: provider.reports[i]),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.appBarGradientStart, AppColors.appBarGradientEnd],
          ),
        ),
      ),
      title: const Text(
        'Reports',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KPI Strip
// ═══════════════════════════════════════════════════════════════════════════════

class _KpiStrip extends StatelessWidget {
  final ReportModel report;
  const _KpiStrip({required this.report});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _KpiTile(
            label: 'Uptime',
            value: '${report.uptimePct.toStringAsFixed(1)}%',
            icon: Icons.check_circle_rounded,
            color: report.uptimePct >= 99
                ? AppColors.online
                : report.uptimePct >= 95
                    ? AppColors.degraded
                    : AppColors.offline,
          ),
          const SizedBox(width: 10),
          _KpiTile(
            label: 'Avg Latency',
            value: '${report.avgLatencyMs.toStringAsFixed(0)} ms',
            icon: Icons.speed_rounded,
            color: AppUtils.latencyColor(report.avgLatencyMs),
          ),
          const SizedBox(width: 10),
          _KpiTile(
            label: 'Alerts',
            value: '${report.totalAlerts}',
            icon: Icons.warning_amber_rounded,
            color: report.totalAlerts > 20
                ? AppColors.offline
                : report.totalAlerts > 5
                    ? AppColors.degraded
                    : AppColors.online,
          ),
          const SizedBox(width: 10),
          _KpiTile(
            label: 'MTTR',
            value: '${report.avgMttrMinutes.toStringAsFixed(0)}m',
            icon: Icons.timer_rounded,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Device Status Bar
// ═══════════════════════════════════════════════════════════════════════════════

class _DeviceStatusBar extends StatelessWidget {
  final ReportModel report;
  const _DeviceStatusBar({required this.report});

  @override
  Widget build(BuildContext context) {
    final total = report.totalDevices;
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device Status', style: AppTextStyles.labelBold),
            const SizedBox(height: 12),
            // ── Stacked bar ──────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    _bar(report.onlineDevices / total, AppColors.online),
                    _bar(report.degradedDevices / total, AppColors.degraded),
                    _bar(report.offlineDevices / total, AppColors.offline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Legend ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legend(AppColors.online, 'Online', report.onlineDevices),
                _legend(AppColors.degraded, 'Degraded', report.degradedDevices),
                _legend(AppColors.offline, 'Offline', report.offlineDevices),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double fraction, Color color) {
    if (fraction <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: (fraction * 100).round().clamp(1, 100),
      child: Container(color: color),
    );
  }

  Widget _legend(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ($count)', style: AppTextStyles.caption),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Alert Severity Chart
// ═══════════════════════════════════════════════════════════════════════════════

class _AlertSeverityChart extends StatelessWidget {
  final ReportModel report;
  const _AlertSeverityChart({required this.report});

  @override
  Widget build(BuildContext context) {
    final data = report.alertsBySeverity;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Alerts by Severity', style: AppTextStyles.labelBold),
                Text(
                  '${report.resolvedAlerts}/${report.totalAlerts} resolved',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.map((item) {
              final severity = item['severity'] as String;
              final count = item['count'] as int;
              final color = AppUtils.severityColor(severity);
              final maxCount = data
                  .map((e) => e['count'] as int)
                  .reduce((a, b) => a > b ? a : b);
              final fraction = maxCount > 0 ? count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        AppUtils.severityLabel(severity),
                        style: AppTextStyles.captionBold.copyWith(color: color),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 10,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$count',
                        style: AppTextStyles.labelBold,
                        textAlign: TextAlign.end,
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// Latency Chart
// ═══════════════════════════════════════════════════════════════════════════════

class _LatencyChart extends StatelessWidget {
  final ReportModel report;
  const _LatencyChart({required this.report});

  @override
  Widget build(BuildContext context) {
    final data = report.dailyLatency!;
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
    }).toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latency Trend', style: AppTextStyles.labelBold),
            const SizedBox(height: 4),
            Text(
              report.type == 'daily' ? 'Hourly average (ms)' : 'Daily average (ms)',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
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
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
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
                          if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                          final label = data[idx].values.first.toString();
                          return Text(
                            label,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textHint,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                        color: AppColors.primary.withValues(alpha: 0.08),
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
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Filter Chips
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterChips extends StatelessWidget {
  final ReportsProvider provider;
  const _FilterChips({required this.provider});

  static const _types = [
    ('all', 'All'),
    ('daily', 'Daily'),
    ('weekly', 'Weekly'),
    ('monthly', 'Monthly'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        children: _types.map((t) {
          final selected = provider.typeFilter == t.$1;
          return FilterChip(
            label: Text(t.$2),
            selected: selected,
            onSelected: (_) => provider.setTypeFilter(t.$1),
            selectedColor: AppColors.primarySurface,
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Report Tile
// ═══════════════════════════════════════════════════════════════════════════════

class _ReportTile extends StatelessWidget {
  final ReportModel report;
  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final isGenerating = report.status == 'generating';
    final isFailed = report.status == 'failed';
    final typeIcon = switch (report.type) {
      'daily' => Icons.today_rounded,
      'weekly' => Icons.date_range_rounded,
      'monthly' => Icons.calendar_month_rounded,
      _ => Icons.description_rounded,
    };
    final typeColor = switch (report.type) {
      'daily' => AppColors.primary,
      'weekly' => AppColors.online,
      'monthly' => AppColors.maintenance,
      _ => AppColors.textSecondary,
    };
    final statusColor = isFailed
        ? AppColors.offline
        : isGenerating
            ? AppColors.degraded
            : AppColors.online;
    final statusLabel = isFailed
        ? 'Failed'
        : isGenerating
            ? 'Generating…'
            : 'Completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isGenerating || isFailed
              ? null
              : () => Navigator.of(context).pushNamed(
                    AppConstants.reportsRoute,
                    arguments: report,
                  ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                // ── Type icon ────────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 12),
                // ── Info ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: AppTextStyles.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppUtils.formatShortDate(report.periodStart)} — ${AppUtils.formatShortDate(report.periodEnd)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Status badge ─────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isGenerating)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: statusColor,
                            ),
                          ),
                        ),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
