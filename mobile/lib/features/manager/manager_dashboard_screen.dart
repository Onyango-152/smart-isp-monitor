import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/metric_model.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ManagerDashboardProvider
// ─────────────────────────────────────────────────────────────────────────────

class ManagerDashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<DeviceModel> _devices = [];
  List<AlertModel>  _alerts  = [];
  List<MetricModel> _metrics = [];

  List<DeviceModel> get devices => _devices;
  List<AlertModel>  get alerts  => _alerts;
  List<MetricModel> get metrics => _metrics;

  int get totalDevices    => devices.length;
  int get onlineDevices   => devices.where((d) => d.status == 'online').length;
  int get offlineDevices  => devices.where((d) => d.status == 'offline').length;
  int get degradedDevices => devices.where((d) => d.status == 'degraded').length;
  int get activeAlerts    => alerts.where((a) => !a.isResolved).length;
  int get resolvedAlerts  => alerts.where((a) =>  a.isResolved).length;

  // Network uptime % — average of all device uptimes derived from metrics
  double get networkUptimePct {
    if (devices.isEmpty) return 0;
    final online   = onlineDevices.toDouble();
    final degraded = degradedDevices.toDouble() * 0.5; // count as half
    return ((online + degraded) / totalDevices) * 100;
  }

  // MTTR — average fault resolution time in hours (from resolved alerts)
  double get mttrHours {
    final resolved = alerts.where((a) => a.isResolved && a.resolvedAt != null);
    if (resolved.isEmpty) return 0;
    double totalMinutes = 0;
    for (final a in resolved) {
      final start = DateTime.tryParse(a.triggeredAt);
      final end   = DateTime.tryParse(a.resolvedAt!);
      if (start != null && end != null) {
        totalMinutes += end.difference(start).inMinutes.toDouble();
      }
    }
    return totalMinutes / resolved.length / 60;
  }

  // Dummy 7-day daily fault counts for the bar chart
  List<int> get weeklyFaultCounts => [3, 1, 5, 2, 4, 2, activeAlerts];

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiClient.getDevices(),
        ApiClient.getAlerts(),
        ApiClient.getMetrics(),
      ]);
      _devices = results[0] as List<DeviceModel>;
      _alerts  = results[1] as List<AlertModel>;
      _metrics = results[2] as List<MetricModel>;
    } catch (_) {
      // Keep stale data if available
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load();
}

// ─────────────────────────────────────────────────────────────────────────────
// ManagerDashboardScreen
// ─────────────────────────────────────────────────────────────────────────────

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManagerDashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ManagerDashboardProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Network Overview'),
            actions: [
              IconButton(
                icon:      const Icon(Icons.refresh),
                onPressed: provider.refresh,
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      // ── KPI row ────────────────────────────────────────
                      _buildKpiRow(provider),
                      const SizedBox(height: 20),

                      // ── Uptime + pie side by side ──────────────────────
                      _buildUptimeAndFleet(provider),
                      const SizedBox(height: 20),

                      // ── 7-day fault bar chart ──────────────────────────
                      _buildWeeklyFaultsChart(provider),
                      const SizedBox(height: 20),

                      // ── Device fleet list ──────────────────────────────
                      _buildFleetList(provider),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ── KPI Row ───────────────────────────────────────────────────────────────

  Widget _buildKpiRow(ManagerDashboardProvider p) {
    return Row(
      children: [
        _KpiCard(
          label: 'Uptime',
          value: '${p.networkUptimePct.toStringAsFixed(1)}%',
          icon:  Icons.timeline,
          color: p.networkUptimePct >= 90 ? AppColors.online : AppColors.severityMedium,
        ),
        const SizedBox(width: 10),
        _KpiCard(
          label: 'Open Alerts',
          value: p.activeAlerts.toString(),
          icon:  Icons.notifications_active,
          color: p.activeAlerts > 0 ? AppColors.severityCritical : AppColors.online,
        ),
        const SizedBox(width: 10),
        _KpiCard(
          label: 'MTTR',
          value: '${p.mttrHours.toStringAsFixed(1)}h',
          icon:  Icons.timer_outlined,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: 10),
        _KpiCard(
          label: 'Devices',
          value: p.totalDevices.toString(),
          icon:  Icons.router,
          color: AppColors.primaryDark,
        ),
      ],
    );
  }

  // ── Uptime ring + fleet pie ────────────────────────────────────────────────

  Widget _buildUptimeAndFleet(ManagerDashboardProvider p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Uptime ring
        Expanded(
          child: _SectionCard(
            title: 'Network Uptime',
            child: SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace:     0,
                      centerSpaceRadius: 46,
                      sections: [
                        PieChartSectionData(
                          value:     p.networkUptimePct,
                          color:     AppColors.online,
                          radius:    18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value:     100 - p.networkUptimePct,
                          color:     AppColors.divider,
                          radius:    18,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${p.networkUptimePct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize:   22,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'uptime',
                        style: TextStyle(fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Fleet status pie
        Expanded(
          child: _SectionCard(
            title: 'Fleet Status',
            child: SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace:     2,
                        centerSpaceRadius: 24,
                        sections: [
                          if (p.onlineDevices > 0)
                            PieChartSectionData(
                              value:     p.onlineDevices.toDouble(),
                              color:     AppColors.online,
                              radius:    30,
                              showTitle: false,
                            ),
                          if (p.degradedDevices > 0)
                            PieChartSectionData(
                              value:     p.degradedDevices.toDouble(),
                              color:     AppColors.severityMedium,
                              radius:    30,
                              showTitle: false,
                            ),
                          if (p.offlineDevices > 0)
                            PieChartSectionData(
                              value:     p.offlineDevices.toDouble(),
                              color:     AppColors.severityCritical,
                              radius:    30,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendDot(color: AppColors.online,           label: 'Online   ${p.onlineDevices}'),
                      const SizedBox(height: 6),
                      _LegendDot(color: AppColors.severityMedium,   label: 'Degraded ${p.degradedDevices}'),
                      const SizedBox(height: 6),
                      _LegendDot(color: AppColors.severityCritical, label: 'Offline  ${p.offlineDevices}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Weekly faults bar chart ───────────────────────────────────────────────

  Widget _buildWeeklyFaultsChart(ManagerDashboardProvider p) {
    final days   = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Today'];
    final counts = p.weeklyFaultCounts;
    final maxY   = (counts.reduce((a, b) => a > b ? a : b) + 2).toDouble();

    return _SectionCard(
      title: 'Faults — Last 7 Days',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY:            maxY,
            gridData:        FlGridData(
              show:              true,
              drawVerticalLine:  false,
              getDrawingHorizontalLine: (_) => FlLine(
                color:       AppColors.divider,
                strokeWidth: 1,
              ),
            ),
            borderData:      FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:   AxisTitles(
                sideTitles: SideTitles(
                  showTitles:    true,
                  reservedSize:  28,
                  interval:      2,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                ),
              ),
              rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles:    true,
                  reservedSize:  24,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= days.length) return const SizedBox.shrink();
                    return Text(
                      days[i],
                      style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(counts.length, (i) {
              final isToday = i == counts.length - 1;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY:          counts[i].toDouble(),
                    color:        isToday ? AppColors.primary : AppColors.primaryLight.withOpacity(0.6),
                    width:        22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Device fleet list ─────────────────────────────────────────────────────

  Widget _buildFleetList(ManagerDashboardProvider p) {
    return _SectionCard(
      title: 'Device Fleet',
      child: Column(
        children: p.devices.map((d) {
          final metric = _metricFor(d.id, p.metrics);
          return _FleetRow(device: d, metric: metric);
        }).toList(),
      ),
    );
  }

  MetricModel? _metricFor(int deviceId, List<MetricModel> metrics) {
    try {
      return metrics.firstWhere((m) => m.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(
              fontSize: 10, color: AppColors.textHint), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          child,
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
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FleetRow extends StatelessWidget {
  final DeviceModel  device;
  final MetricModel? metric;
  const _FleetRow({required this.device, this.metric});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppUtils.statusColor(device.status);
    final latency     = metric?.latencyMs != null
        ? '${metric!.latencyMs!.toStringAsFixed(0)} ms'
        : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(device.location ?? device.ipAddress,
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(latency, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Text('latency', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}
