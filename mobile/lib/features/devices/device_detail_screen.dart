import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/info_row.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../data/models/alert_model.dart';
import 'device_detail_provider.dart';

class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve the Device object passed as a navigation argument
    final arguments = ModalRoute.of(context)?.settings.arguments;
    
    if (arguments == null || arguments is! DeviceModel) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Device Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.offline),
              const SizedBox(height: 12),
              const Text(
                'Invalid device data. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final device = arguments as DeviceModel?;
    
    if (device == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Device Details')),
        body: const Center(
          child: Text('Device not found'),
        ),
      );
    }

    return ChangeNotifierProvider(
      // Create the provider scoped to this screen only.
      // It is automatically destroyed when the screen is popped.
      create: (_) => DeviceDetailProvider(device: device)..loadDeviceData(),
      child: const _DeviceDetailContent(),
    );
  }
}

/// _DeviceDetailContent is separated from DeviceDetailScreen so that
/// the ChangeNotifierProvider above can provide data to this widget.
class _DeviceDetailContent extends StatelessWidget {
  const _DeviceDetailContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDetailProvider>(
      builder: (context, provider, _) {
        final device = provider.device;

        return Scaffold(
          backgroundColor: AppColors.background,

          // ── App Bar ───────────────────────────────────────────────────
          appBar: AppBar(
            title: Text(device.name),
            actions: [
              // Refresh button
              IconButton(
                icon:      const Icon(Icons.refresh),
                onPressed: provider.refresh,
              ),
            ],
          ),

          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.errorMessage != null
                  ? _buildErrorState(context, provider)
                  : RefreshIndicator(
                      onRefresh: provider.refresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── 1. Status Header Card ─────────────────────
                            _buildStatusHeader(device, provider),

                            // ── 2. Live Metrics Grid ──────────────────────
                            _buildMetricsSection(provider),

                            // ── 3. Latency Chart ──────────────────────────
                            _buildLatencyChart(provider),

                            // ── 4. Device Info ────────────────────────────
                            _buildDeviceInfo(device),

                            // ── 5. Active Alerts ──────────────────────────
                            _buildAlertsSection(context, provider),

                            // ── 6. Action Buttons ─────────────────────────
                            _buildActionButtons(context, device),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 1 — Status Header
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStatusHeader(
      DeviceModel device, DeviceDetailProvider provider) {
    return Container(
      width:   double.infinity,
      margin:  const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Device name, type icon, and status badge
          Row(
            children: [
              Container(
                width:      48,
                height:     48,
                decoration: BoxDecoration(
                  color:        AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AppUtils.deviceTypeIcon(device.deviceType),
                  color: AppColors.primary,
                  size:  26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      AppUtils.deviceTypeLabel(device.deviceType),
                      style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: device.status),
            ],
          ),

          const Divider(height: 24),

          // Quick stats row — IP, location, last seen
          Row(
            children: [
              _QuickStat(
                icon:  Icons.router,
                label: 'IP Address',
                value: device.ipAddress,
              ),
              _QuickStat(
                icon:  Icons.location_on_outlined,
                label: 'Location',
                value: device.location ?? 'Not set',
              ),
              _QuickStat(
                icon:  Icons.access_time,
                label: 'Last Seen',
                value: AppUtils.timeAgo(device.lastSeen),
              ),
            ],
          ),

          // Active alerts badge if any
          if (provider.activeAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding:    const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        AppColors.offlineLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppColors.offline, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${provider.activeAlerts.length} active alert'
                    '${provider.activeAlerts.length > 1 ? "s" : ""}'
                    ' on this device',
                    style: const TextStyle(
                      color:      AppColors.offline,
                      fontSize:   13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 2 — Live Metrics Grid
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMetricsSection(DeviceDetailProvider provider) {
    final metric = provider.latestMetric;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Live Metrics'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: metric == null
              ? Container(
                  padding:    const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No metrics available yet.\nThis device has not been polled.',
                      textAlign: TextAlign.center,
                      style:     TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : GridView.count(
                  // GridView.count creates a fixed 2-column grid
                  crossAxisCount:   2,
                  shrinkWrap:       true,
                  // shrinkWrap=true means the grid only takes as much
                  // height as it needs, not the full screen height.
                  // This allows it to live inside a SingleChildScrollView.
                  physics:          const NeverScrollableScrollPhysics(),
                  // NeverScrollableScrollPhysics prevents the grid from
                  // scrolling independently — the parent scroll view handles it.
                  crossAxisSpacing: 10,
                  mainAxisSpacing:  10,
                  childAspectRatio: 1.4,
                  children: [
                    MetricCard(
                      label:      'Latency',
                      value:      metric.latencyMs != null
                          ? metric.latencyMs!.toStringAsFixed(1)
                          : 'N/A',
                      unit:       'ms',
                      icon:       Icons.speed,
                      isAlert:    (metric.latencyMs ?? 0) > 200,
                      valueColor: metric.latencyMs != null
                          ? AppUtils.statusColor(
                              metric.latencyMs! < 50
                                  ? 'online'
                                  : metric.latencyMs! < 200
                                      ? 'degraded'
                                      : 'offline')
                          : null,
                    ),
                    MetricCard(
                      label:   'Packet Loss',
                      value:   metric.packetLossPct != null
                          ? metric.packetLossPct!.toStringAsFixed(1)
                          : 'N/A',
                      unit:    '%',
                      icon:    Icons.signal_wifi_bad,
                      isAlert: (metric.packetLossPct ?? 0) > 5,
                    ),
                    MetricCard(
                      label:   'CPU Usage',
                      value:   metric.cpuUsagePct != null
                          ? metric.cpuUsagePct!.toStringAsFixed(0)
                          : 'N/A',
                      unit:    '%',
                      icon:    Icons.memory,
                      isAlert: (metric.cpuUsagePct ?? 0) > 80,
                    ),
                    MetricCard(
                      label:   'Memory',
                      value:   metric.memoryUsagePct != null
                          ? metric.memoryUsagePct!.toStringAsFixed(0)
                          : 'N/A',
                      unit:    '%',
                      icon:    Icons.storage,
                      isAlert: (metric.memoryUsagePct ?? 0) > 85,
                    ),
                    MetricCard(
                      label: 'Bandwidth In',
                      value: AppUtils.formatBandwidth(metric.bandwidthInBps),
                      icon:  Icons.arrow_downward,
                    ),
                    MetricCard(
                      label: 'Uptime',
                      value: AppUtils.formatUptime(metric.uptimeSeconds),
                      icon:  Icons.timer_outlined,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 3 — Latency Chart
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLatencyChart(DeviceDetailProvider provider) {
    final history = provider.metricsHistory;

    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Latency — Last 24 Hours'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Container(
              height:     200,
              padding:    const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: RepaintBoundary(
                child: LineChart(
                  _buildLineChartData(history),
                ),
              ),
            ),
          ),
        ),

        // Chart legend
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Latency (ms)'),
              const SizedBox(width: 16),
              _LegendDot(
                  color: AppColors.offline.withOpacity(0.3),
                  label: 'Threshold (200ms)'),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the fl_chart LineChartData object.
  LineChartData _buildLineChartData(List<MetricModel> history) {
    // Convert metric history into chart data points.
    // FlSpot(x, y) where x is the hour index and y is the latency value.
    final spots = history.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.latencyMs ?? 0,
      );
    }).toList();

    // Threshold line at 200ms shown as a horizontal dashed line
    final thresholdSpots = [
      FlSpot(0, 200),
      FlSpot(history.length.toDouble() - 1, 200),
    ];

    return LineChartData(
      // Grid lines configuration
      gridData: FlGridData(
        show:               true,
        drawVerticalLine:   false,
        horizontalInterval: 100,
        getDrawingHorizontalLine: (value) => FlLine(
          color:       AppColors.divider,
          strokeWidth: 1,
        ),
      ),

      // Axis label configuration
      titlesData: FlTitlesData(
        // Hide right and top axis labels
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),

        // Left axis — latency values
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles:   true,
            reservedSize: 36,
            interval:     100,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}',
              style: const TextStyle(
                fontSize: 10,
                color:    AppColors.textHint,
              ),
            ),
          ),
        ),

        // Bottom axis — hours ago
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles:   true,
            reservedSize: 22,
            interval:     6, // show label every 6 hours
            getTitlesWidget: (value, meta) {
              final hoursAgo = history.length - 1 - value.toInt();
              if (hoursAgo == 0) return const Text('Now',
                  style: TextStyle(fontSize: 9, color: AppColors.textHint));
              if (hoursAgo % 6 == 0) return Text('${hoursAgo}h',
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textHint));
              return const SizedBox.shrink();
            },
          ),
        ),
      ),

      // Chart border
      borderData: FlBorderData(
        show:   true,
        border: Border(
          left:   const BorderSide(color: AppColors.divider),
          bottom: const BorderSide(color: AppColors.divider),
        ),
      ),

      // Y axis range — always show at least 0 to 300ms
      minY: 0,
      maxY: (history.map((m) => m.latencyMs ?? 0).reduce(
                  (a, b) => a > b ? a : b) +
              50)
          .clamp(300, 600),

      lineBarsData: [
        // Main latency line
        LineChartBarData(
          spots:          spots,
          isCurved:       true,
          // isCurved=true makes the line smooth rather than angular
          curveSmoothness: 0.3,
          color:          AppColors.primary,
          barWidth:       2.5,
          isStrokeCapRound: true,
          dotData:        const FlDotData(show: false),
          // Gradient fill below the line
          belowBarData: BarAreaData(
            show:  true,
            color: AppColors.primary.withOpacity(0.08),
          ),
        ),

        // Threshold line at 200ms
        LineChartBarData(
          spots:    thresholdSpots,
          isCurved: false,
          color:    AppColors.offline.withOpacity(0.4),
          barWidth: 1.5,
          dashArray: [6, 4], // dashed line pattern
          dotData:  const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],

      // Touch interaction — show tooltip when user taps/hovers on the chart
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots.map((spot) {
              if (spot.barIndex == 1) return null; // hide threshold tooltip
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} ms',
                const TextStyle(
                  color:      Colors.white,
                  fontSize:   12,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 4 — Device Information
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDeviceInfo(DeviceModel device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Device Information'),
        Container(
          margin:     const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.04),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            children: [
              InfoRow(
                label: 'IP Address',
                value: device.ipAddress,
                icon:  Icons.router,
              ),
              InfoRow(
                label: 'MAC Address',
                value: device.macAddress ?? 'Not available',
                icon:  Icons.device_hub,
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
                value: device.snmpEnabled
                    ? 'Enabled (${device.snmpCommunity})'
                    : 'Disabled',
                icon:       Icons.settings_ethernet,
                valueColor: device.snmpEnabled
                    ? AppColors.online
                    : AppColors.textSecondary,
              ),
              InfoRow(
                label:  'Description',
                value:  device.description ?? 'No description',
                icon:   Icons.notes,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 5 — Active Alerts
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAlertsSection(
      BuildContext context, DeviceDetailProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title:       'Active Alerts',
          actionLabel: 'View All',
          onAction:    () {
            Navigator.of(context).pushNamed(
              AppConstants.alertRoute,
              arguments: provider.activeAlerts,
            );
          },
        ),
        if (provider.activeAlerts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding:    const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColors.onlineLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.online.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppColors.online, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'No active alerts on this device',
                    style: TextStyle(
                      color:      AppColors.online,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...provider.activeAlerts.map(
            (alert) => _AlertTile(alert: alert),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 6 — Action Buttons
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context, DeviceModel device) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        children: [
          // Run Diagnostic — primary action
          ElevatedButton.icon(
            onPressed: () {
              debugPrint('Navigating to DiagnosticScreen with device: \\${device.id}');
              Navigator.of(context).pushNamed(
                AppConstants.diagnosticRoute,
                arguments: device,
              );
            },
            icon:  const Icon(Icons.network_ping),
            label: const Text('Run Diagnostic'),
          ),
          const SizedBox(height: 10),

          // Troubleshoot — secondary action
          OutlinedButton.icon(
            onPressed: () {
              debugPrint('Navigating to TroubleshootScreen with device: \\${device.id}');
              Navigator.of(context).pushNamed(
                AppConstants.troubleshootRoute,
                arguments: device,
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize:   const Size(double.infinity, 52),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon:  const Icon(Icons.build_outlined),
            label: const Text('Troubleshoot',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, DeviceDetailProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.offline),
          const SizedBox(height: 12),
          Text(provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: provider.loadDeviceData,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(140, 44)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper widgets
// ─────────────────────────────────────────────────────────────────────────────

/// _QuickStat shows a small icon + label + value used in the status header.
class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color:    AppColors.textHint,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color:      AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            overflow:  TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// _AlertTile renders a single alert as a compact card on the detail screen.
class _AlertTile extends StatelessWidget {
  final AlertModel alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final severityColor = AppUtils.severityColor(alert.severity);

    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: severityColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alert type label
                Text(
                  alert.alertType
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.bold,
                    color:      severityColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),

                // Alert message
                Text(
                  alert.message,
                  style: const TextStyle(
                    fontSize: 13,
                    color:    AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // Time ago
                Text(
                  AppUtils.timeAgo(alert.triggeredAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color:    AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          // Acknowledged badge
          if (alert.isAcknowledged)
            Container(
              padding:    const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        AppColors.primarySurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ACK',
                style: TextStyle(
                  fontSize:   10,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// _LegendDot is the small coloured dot used in the chart legend.
class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:      10,
          height:     10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color:    AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Simple StatusBadge used on the device header when the shared widget is
/// not available; shows a colored pill with the status text.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.statusColor(status);
    final label = (status.isNotEmpty)
        ? '${status[0].toUpperCase()}${status.substring(1)}'
        : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}