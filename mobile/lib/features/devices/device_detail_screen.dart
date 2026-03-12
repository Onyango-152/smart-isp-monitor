import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import 'device_detail_provider.dart';
import 'device_provider.dart';

class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = ModalRoute.of(context)?.settings.arguments;
    if (device == null || device is! DeviceModel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device Detail')),
        body: EmptyState(
          icon:    Icons.error_outline_rounded,
          title:   'No Device Data',
          message: 'No device was passed to this screen.\nGo back and tap a device from the list.',
          color:   AppColors.offline,
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => DeviceDetailProvider(device: device)..loadDeviceData(),
      child:  const _DeviceDetailContent(),
    );
  }
}

class _DeviceDetailContent extends StatelessWidget {
  const _DeviceDetailContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDetailProvider>(
      builder: (context, provider, _) {
        final device = provider.device;
        return Scaffold(
          body: provider.isLoading
              ? _buildLoadingState(context, device)
              : provider.errorMessage != null
                  ? _buildErrorState(context, device, provider)
                  : _buildContent(context, device, provider),
        );
      },
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoadingState(BuildContext context, DeviceModel device) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, device, null),
        SliverFillRemaining(
          child: ShimmerSkeleton.deviceDetail(),
        ),
      ],
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState(
      BuildContext context, DeviceModel device, DeviceDetailProvider provider) {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, device, provider),
        SliverFillRemaining(
          child: EmptyState(
            icon:        Icons.cloud_off_rounded,
            title:       'Could Not Load Device',
            message:     provider.errorMessage!,
            color:       AppColors.offline,
            actionLabel: 'Retry',
            onAction:    provider.loadDeviceData,
          ),
        ),
      ],
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent(
      BuildContext context, DeviceModel device, DeviceDetailProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.refresh,
      color:     AppColors.primary,
      edgeOffset: 120,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, device, provider),
          SliverToBoxAdapter(child: _buildQuickStatsStrip(context, device, provider)),
          SliverToBoxAdapter(child: _buildMetricsSection(context, provider)),
          SliverToBoxAdapter(child: _buildLatencyChart(context, provider)),
          SliverToBoxAdapter(child: _buildDeviceInfo(context, device)),
          SliverToBoxAdapter(child: _buildAlertsSection(context, provider)),
          SliverToBoxAdapter(child: _buildDiagnosticHistory(context, provider)),
          SliverToBoxAdapter(child: _buildActionButtons(context, device)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Sliver App Bar — hero gradient with device icon + status ─────────────
  // ══════════════════════════════════════════════════════════════════════════

  SliverAppBar _buildSliverAppBar(
      BuildContext context, DeviceModel device, DeviceDetailProvider? provider) {
    final statusColor = AppUtils.statusColor(device.status);
    return SliverAppBar(
      expandedHeight: 190,
      pinned: true,
      elevation: 0,
      stretch: true,
      leading: _CircleBackButton(onTap: () => Navigator.of(context).pop()),
      actions: [
        if (provider != null)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              AppUtils.haptic();
              provider.refresh();
            },
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                Navigator.of(context).pushNamed(
                  AppConstants.deviceFormRoute,
                  arguments: device,
                ).then((updated) {
                  if (updated == true) {
                    AppUtils.showSnackbar(context, 'Device updated');
                    provider?.refresh();
                  }
                });
              case 'delete':
                _showDeleteDialog(context, device);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Edit Device'),
              ]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_rounded, size: 18, color: AppColors.offline),
                SizedBox(width: 10),
                Text('Delete Device', style: TextStyle(color: AppColors.offline)),
              ]),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [AppColors.appBarGradientStart, AppColors.appBarGradientEnd],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Icon + name ─────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25), width: 1.5),
                        ),
                        child: Icon(
                          AppUtils.deviceTypeIcon(device.deviceType),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppUtils.deviceTypeLabel(device.deviceType),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Status pill + IP ────────────────────────────────
                  Row(
                    children: [
                      _StatusPill(status: device.status, color: statusColor),
                      const SizedBox(width: 12),
                      Icon(Icons.lan_rounded,
                          size: 14, color: Colors.white.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        device.ipAddress,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
        title: Text(device.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Quick Stats Strip ────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickStatsStrip(BuildContext context, DeviceModel device, DeviceDetailProvider provider) {
    final uptimeColor = provider.deviceUptimePct >= 99
        ? AppColors.online
        : provider.deviceUptimePct >= 95
            ? AppColors.degraded
            : AppColors.offline;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // ── Top row: 3 key stats ───────────────────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                _InfoChip(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  value: device.location ?? 'Not set',
                  color: AppColors.primary,
                ),
                _VerticalDot(),
                _InfoChip(
                  icon: Icons.access_time_rounded,
                  label: 'Last Seen',
                  value: AppUtils.timeAgo(device.lastSeen),
                  color: AppColors.textSecondaryOf(context),
                ),
                _VerticalDot(),
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Added',
                  value: AppUtils.formatShortDate(device.createdAt),
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Uptime bar ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: uptimeColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: uptimeColor.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.signal_cellular_alt_rounded, size: 16, color: uptimeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('7-Day Uptime',
                              style: AppTextStyles.caption.copyWith(
                                  color: uptimeColor, fontWeight: FontWeight.w600)),
                          Text('${provider.deviceUptimePct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: uptimeColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (provider.deviceUptimePct / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: uptimeColor.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(uptimeColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Active alerts warning ──────────────────────────────────
          if (provider.activeAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.offlineLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.offline.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: AppColors.offline, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${provider.activeAlerts.length} active alert${provider.activeAlerts.length > 1 ? "s" : ""}',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.offline, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Metrics Section — inline cards with circular indicators ──────────────
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMetricsSection(BuildContext context, DeviceDetailProvider provider) {
    final metric = provider.latestMetric;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Live Metrics', style: AppTextStyles.heading2),
              const Spacer(),
              if (metric != null)
                Text(
                  'Polled ${AppUtils.timeAgo(metric.recordedAt)}',
                  style: AppTextStyles.caption,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (metric == null)
          _buildNoMetrics(context)
        else
          _buildMetricGrid(metric),
      ],
    );
  }

  Widget _buildNoMetrics(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySurfaceOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sensors_off_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No Metrics Yet', style: AppTextStyles.heading3),
                  const SizedBox(height: 2),
                  Text('Device has not been polled.',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid(MetricModel metric) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Row 1: Latency + Packet Loss ────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Latency',
                  value: metric.latencyMs != null
                      ? metric.latencyMs!.toStringAsFixed(1)
                      : 'N/A',
                  unit: 'ms',
                  icon: Icons.speed_rounded,
                  progress: metric.latencyMs != null
                      ? (metric.latencyMs! / 300).clamp(0.0, 1.0)
                      : null,
                  color: _latencyColor(metric.latencyMs),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Packet Loss',
                  value: metric.packetLossPct != null
                      ? metric.packetLossPct!.toStringAsFixed(1)
                      : 'N/A',
                  unit: '%',
                  icon: Icons.signal_wifi_bad_rounded,
                  progress: metric.packetLossPct != null
                      ? (metric.packetLossPct! / 100).clamp(0.0, 1.0)
                      : null,
                  color: _pctColor(metric.packetLossPct, warnAt: 5, critAt: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Row 2: CPU + Memory ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'CPU Usage',
                  value: metric.cpuUsagePct != null
                      ? metric.cpuUsagePct!.toStringAsFixed(0)
                      : 'N/A',
                  unit: '%',
                  icon: Icons.memory_rounded,
                  progress: metric.cpuUsagePct != null
                      ? (metric.cpuUsagePct! / 100).clamp(0.0, 1.0)
                      : null,
                  color: _pctColor(metric.cpuUsagePct, warnAt: 75, critAt: 90),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Memory',
                  value: metric.memoryUsagePct != null
                      ? metric.memoryUsagePct!.toStringAsFixed(0)
                      : 'N/A',
                  unit: '%',
                  icon: Icons.storage_rounded,
                  progress: metric.memoryUsagePct != null
                      ? (metric.memoryUsagePct! / 100).clamp(0.0, 1.0)
                      : null,
                  color: _pctColor(metric.memoryUsagePct, warnAt: 80, critAt: 90),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Row 3: Bandwidth + Uptime ───────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Bandwidth In',
                  value: AppUtils.formatBandwidth(metric.bandwidthInBps),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Uptime',
                  value: AppUtils.formatUptime(metric.uptimeSeconds),
                  icon: Icons.timer_rounded,
                  color: AppColors.online,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _latencyColor(double? ms) {
    if (ms == null) return AppColors.textHint;
    if (ms >= 200) return AppColors.offline;
    if (ms >= 100) return AppColors.degraded;
    return AppColors.online;
  }

  Color _pctColor(double? pct, {required double warnAt, required double critAt}) {
    if (pct == null) return AppColors.textHint;
    if (pct >= critAt) return AppColors.offline;
    if (pct >= warnAt) return AppColors.degraded;
    return AppColors.online;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Latency Trend Chart ──────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLatencyChart(BuildContext context, DeviceDetailProvider provider) {
    final history = provider.metricsHistory;
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Latency Trend', style: AppTextStyles.heading2),
              const Spacer(),
              Text('Last 7 days', style: AppTextStyles.caption),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 210,
            padding: const EdgeInsets.fromLTRB(0, 20, 12, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.card,
            ),
            child: LineChart(_buildLineChartData(context, history)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Latency (ms)'),
              const SizedBox(width: 16),
              _LegendDot(
                  color: AppColors.offline.withOpacity(0.4),
                  label: 'Threshold (200 ms)'),
            ],
          ),
        ),
      ],
    );
  }

  LineChartData _buildLineChartData(BuildContext context, List<MetricModel> history) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.latencyMs ?? 0))
        .toList();
    final thresholdSpots = [
      FlSpot(0, 200),
      FlSpot((history.length - 1).toDouble(), 200),
    ];
    final maxLatency = history
        .map((m) => m.latencyMs ?? 0)
        .fold(0.0, (a, b) => a > b ? a : b);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 100,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.dividerOf(context),
          strokeWidth: 0.8,
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 100,
            getTitlesWidget: (v, _) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('${v.toInt()}',
                  style: AppTextStyles.caption, textAlign: TextAlign.right),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= history.length)
                return const SizedBox.shrink();
              final isLast = idx == history.length - 1;
              final isFirst = idx == 0;
              if (!isFirst && !isLast && idx % 2 != 0)
                return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  isLast
                      ? 'Today'
                      : AppUtils.formatShortDate(history[idx].recordedAt),
                  style: AppTextStyles.caption,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: AppColors.dividerOf(context)),
          bottom: BorderSide(color: AppColors.dividerOf(context)),
        ),
      ),
      minY: 0,
      maxY: (maxLatency + 50).clamp(300, 600),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: AppColors.primary,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 3,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: AppColors.primary,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.primary.withOpacity(0.0),
              ],
            ),
          ),
        ),
        LineChartBarData(
          spots: thresholdSpots,
          isCurved: false,
          color: AppColors.offline.withOpacity(0.4),
          barWidth: 1.5,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.primary,
          tooltipRoundedRadius: 8,
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          getTooltipItems: (spots) => spots.map((spot) {
            if (spot.barIndex == 1) return null;
            return LineTooltipItem(
              '${spot.y.toStringAsFixed(1)} ms',
              const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Device Information ───────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDeviceInfo(BuildContext context, DeviceModel device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Device Information', style: AppTextStyles.heading2),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              InfoRow(
                label: 'IP Address',
                value: device.ipAddress,
                icon:  Icons.lan_rounded,
                isMono: true,
                copyable: true,
              ),
              InfoRow(
                label: 'MAC Address',
                value: device.macAddress ?? 'N/A',
                icon:  Icons.fingerprint_rounded,
                isMono: true,
                copyable: device.macAddress != null,
              ),
              InfoRow(
                label: 'Device Type',
                value: AppUtils.deviceTypeLabel(device.deviceType),
                icon:  Icons.category_outlined,
              ),
              InfoRow(
                label: 'Location',
                value: device.location ?? 'Not set',
                icon:  Icons.location_on_outlined,
              ),
              InfoRow(
                label: 'SNMP',
                value: device.snmpEnabled ? 'Enabled' : 'Disabled',
                icon:  Icons.settings_ethernet_rounded,
                valueColor:
                    device.snmpEnabled ? AppColors.online : AppColors.textSecondaryOf(context),
              ),
              if (device.snmpEnabled)
                InfoRow(
                  label: 'SNMP Community',
                  value: device.snmpCommunity,
                  icon:  Icons.vpn_key_rounded,
                  isMono: true,
                  copyable: true,
                ),
              InfoRow(
                label: 'Description',
                value: device.description ?? 'No description',
                icon:  Icons.notes_rounded,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Active Alerts Section ────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAlertsSection(
      BuildContext context, DeviceDetailProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: provider.activeAlerts.isEmpty
                      ? AppColors.online
                      : AppColors.degraded,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Active Alerts', style: AppTextStyles.heading2),
              const Spacer(),
              Text(
                provider.activeAlerts.isEmpty
                    ? 'All clear'
                    : '${provider.activeAlerts.length} open',
                style: AppTextStyles.caption.copyWith(
                  color: provider.activeAlerts.isEmpty
                      ? AppColors.online
                      : AppColors.degraded,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (provider.activeAlerts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.onlineLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.online.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.online.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.online, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No Active Alerts',
                          style: AppTextStyles.heading3.copyWith(
                              color: AppColors.online)),
                      const SizedBox(height: 2),
                      Text('This device is operating normally.',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          ...provider.activeAlerts.map((alert) => _AlertTile(alert: alert)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Diagnostic History ───────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDiagnosticHistory(BuildContext context, DeviceDetailProvider provider) {
    final history = provider.diagnosticHistory;
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Diagnostic History', style: AppTextStyles.heading2),
              const Spacer(),
              Text(
                'Last ${history.length} run${history.length > 1 ? "s" : ""}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: history.asMap().entries.map((entry) {
                final idx = entry.key;
                final snap = entry.value;
                final isLast = idx == history.length - 1;
                return _DiagnosticHistoryTile(
                    snapshot: snap, isLast: isLast);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Action Buttons ───────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildActionButtons(BuildContext context, DeviceModel device) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        children: [
          // ── Primary: Run Diagnostic ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.appBarGradientStart, AppColors.appBarGradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  AppUtils.haptic();
                  Navigator.of(context).pushNamed(
                      AppConstants.diagnosticRoute,
                      arguments: device);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.network_ping_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Run Diagnostic',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Secondary: Troubleshoot ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              color: AppColors.primarySurfaceOf(context),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  AppUtils.haptic();
                  Navigator.of(context).pushNamed(
                      AppConstants.troubleshootRoute,
                      arguments: device);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.build_rounded,
                          color: AppColors.primary, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Troubleshoot',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete confirmation ─────────────────────────────────────────────────

  void _showDeleteDialog(BuildContext context, DeviceModel device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Device'),
        content: Text(
          'Are you sure you want to delete "${device.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.offline,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // close dialog
              final provider = context.read<DeviceProvider>();
              await provider.deleteDevice(device.id);
              if (context.mounted) {
                Navigator.of(context).pop(); // back to list
                AppUtils.showSnackbar(context, '"${device.name}" deleted');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Circular back button with translucent backdrop for the SliverAppBar.
class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.white.withOpacity(0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Status pill with animated pulsing dot shown in the hero header.
class _StatusPill extends StatefulWidget {
  final String status;
  final Color  color;
  const _StatusPill({required this.status, required this.color});

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _label {
    switch (widget.status.toLowerCase()) {
      case 'online':   return 'Online';
      case 'offline':  return 'Offline';
      case 'degraded': return 'Degraded';
      default:         return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulse,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info chip used in the quick stats strip.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.7)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.labelBold,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Vertical dot separator for the info chip row.
class _VerticalDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.divider,
    );
  }
}

/// Custom metric tile with optional circular progress indicator.
class _MetricTile extends StatelessWidget {
  final String   label;
  final String   value;
  final String?  unit;
  final IconData icon;
  final double?  progress;
  final Color    color;

  const _MetricTile({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.progress,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // ── Circular indicator or icon box ────────────────────────
          if (progress != null)
            SizedBox(
              width: 44, height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44, height: 44,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Icon(icon, size: 18, color: color),
                ],
              ),
            )
          else
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
          const SizedBox(width: 12),
          // ── Text ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 2),
                      Text(
                        unit!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertModel alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.severityColor(alert.severity);
    final bg    = AppUtils.severityBgColor(alert.severity);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.alertType.replaceAll('_', ' ').toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(alert.message, style: AppTextStyles.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      AppUtils.timeAgo(alert.triggeredAt),
                      style: AppTextStyles.caption,
                    ),
                    if (alert.isAcknowledged) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurfaceOf(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACK',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _DiagnosticHistoryTile extends StatelessWidget {
  final DiagnosticSnapshot snapshot;
  final bool isLast;
  const _DiagnosticHistoryTile({required this.snapshot, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = snapshot.passed ? AppColors.online : AppColors.offline;
    final bg    = snapshot.passed ? AppColors.onlineLight : AppColors.offlineLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              snapshot.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.passed ? 'Passed' : 'Failed',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  AppUtils.timeAgo(snapshot.timestamp.toIso8601String()),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                snapshot.avgLatency != null
                    ? '${snapshot.avgLatency!.toStringAsFixed(1)} ms'
                    : 'N/A',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${snapshot.packetLossPct.toStringAsFixed(0)}% loss',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
