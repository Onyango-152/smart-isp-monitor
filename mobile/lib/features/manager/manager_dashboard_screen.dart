import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../features/auth/auth_provider.dart';
import '../../services/api_client.dart';

class ManagerDashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  List<DeviceModel> _devices = [];
  List<AlertModel> _alerts = [];
  List<MetricModel> _metrics = [];

  bool get isLoading => _isLoading;
  List<DeviceModel> get devices => _devices;
  List<AlertModel> get alerts => _alerts;
  List<MetricModel> get metrics => _metrics;

  int get totalDevices => devices.length;
  int get onlineDevices => devices.where((d) => d.status == 'online').length;
  int get offlineDevices => devices.where((d) => d.status == 'offline').length;
  int get degradedDevices =>
      devices.where((d) => d.status == 'degraded').length;
  int get activeAlerts => alerts.where((a) => !a.isResolved).length;
  int get resolvedAlerts => alerts.where((a) => a.isResolved).length;
  int get customerReportedActive =>
      alerts.where((a) => a.customerReported && !a.isResolved).length;

  double get networkUptimePct {
    if (devices.isEmpty) return 0;
    final online = onlineDevices.toDouble();
    final degraded = degradedDevices.toDouble() * 0.5;
    return ((online + degraded) / totalDevices) * 100;
  }

  double get mttrHours {
    final resolved =
        alerts.where((a) => a.isResolved && a.resolvedAt != null).toList();
    if (resolved.isEmpty) return 0;

    double totalMinutes = 0;
    for (final alert in resolved) {
      final start = DateTime.tryParse(alert.triggeredAt);
      final end = DateTime.tryParse(alert.resolvedAt!);
      if (start != null && end != null) {
        totalMinutes += end.difference(start).inMinutes.toDouble();
      }
    }

    return totalMinutes / resolved.length / 60;
  }

  List<int> get weeklyFaultCounts {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return _alerts.where((alert) {
        final timestamp = DateTime.tryParse(alert.triggeredAt);
        return timestamp != null &&
            timestamp.year == day.year &&
            timestamp.month == day.month &&
            timestamp.day == day.day;
      }).length;
    });
  }

  List<String> get weeklyDayLabels {
    final now = DateTime.now();
    const short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (index) {
      if (index == 6) return 'Today';
      final day = now.subtract(Duration(days: 6 - index));
      return short[day.weekday - 1];
    });
  }

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
      _alerts = results[1] as List<AlertModel>;
      _metrics = results[2] as List<MetricModel>;
    } catch (e) {
      // Log error for debugging
      debugPrint('ManagerDashboard load error: $e');
      // Keep stale data if available.
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load();
}

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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ManagerDashboardProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 64,
            flexibleSpace: Container(
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
            ),
            title: Consumer<AuthProvider>(
              builder: (_, auth, __) {
                final firstName =
                    (auth.currentUser?.username ?? 'Manager').split(' ').first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${_greeting()}, $firstName',
                      style: AppTextStyles.appBarTitle.copyWith(fontSize: 15),
                    ),
                    Text(
                      'Network Operations Centre',
                      style: AppTextStyles.appBarSubtitle.copyWith(
                        fontSize: 11,
                        color: AppColors.textOnDark.withOpacity(0.6),
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.textOnDark),
                tooltip: 'Refresh',
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
                      _buildKpiRow(provider),
                      const SizedBox(height: 20),
                      _buildUptimeAndFleet(provider),
                      const SizedBox(height: 20),
                      _buildWeeklyFaultsChart(provider),
                      const SizedBox(height: 20),
                      _buildFleetList(provider),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildKpiRow(ManagerDashboardProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            _KpiCard(
              label: 'Uptime',
              value: '${provider.networkUptimePct.toStringAsFixed(1)}%',
              icon: Icons.timeline,
              color: provider.networkUptimePct >= 90
                  ? AppColors.primary
                  : AppColors.primaryLight,
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Open Alerts',
              value: provider.activeAlerts.toString(),
              icon: Icons.notifications_active,
              color: provider.activeAlerts > 0
                  ? AppColors.primaryDark
                  : AppColors.primary,
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'MTTR',
              value: '${provider.mttrHours.toStringAsFixed(1)}h',
              icon: Icons.timer_outlined,
              color: AppColors.primaryLight,
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Devices',
              value: provider.totalDevices.toString(),
              icon: Icons.router,
              color: AppColors.primaryDark,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _KpiCard(
              label: 'Customer Reports',
              value: provider.customerReportedActive.toString(),
              icon: Icons.report_problem_rounded,
              color: provider.customerReportedActive > 0
                  ? AppColors.primaryDark
                  : AppColors.primary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUptimeAndFleet(ManagerDashboardProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      sectionsSpace: 0,
                      centerSpaceRadius: 46,
                      sections: [
                        PieChartSectionData(
                          value: provider.networkUptimePct,
                          color: AppColors.primary,
                          radius: 18,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: 100 - provider.networkUptimePct,
                          color: AppColors.dividerOf(context),
                          radius: 18,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${provider.networkUptimePct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      Text(
                        'uptime',
                        style: TextStyle(
                          fontSize: 11, 
                          color: AppColors.textHintOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
                        sectionsSpace: 2,
                        centerSpaceRadius: 24,
                        sections: [
                          if (provider.onlineDevices > 0)
                            PieChartSectionData(
                              value: provider.onlineDevices.toDouble(),
                              color: AppColors.primary,
                              radius: 30,
                              showTitle: false,
                            ),
                          if (provider.degradedDevices > 0)
                            PieChartSectionData(
                              value: provider.degradedDevices.toDouble(),
                              color: AppColors.primaryLight,
                              radius: 30,
                              showTitle: false,
                            ),
                          if (provider.offlineDevices > 0)
                            PieChartSectionData(
                              value: provider.offlineDevices.toDouble(),
                              color: AppColors.primaryDark,
                              radius: 30,
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
                      _LegendDot(
                        color: AppColors.primary,
                        label: 'Online   ${provider.onlineDevices}',
                      ),
                      const SizedBox(height: 6),
                      _LegendDot(
                        color: AppColors.primaryLight,
                        label: 'Degraded ${provider.degradedDevices}',
                      ),
                      const SizedBox(height: 6),
                      _LegendDot(
                        color: AppColors.primaryDark,
                        label: 'Offline  ${provider.offlineDevices}',
                      ),
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

  Widget _buildWeeklyFaultsChart(ManagerDashboardProvider provider) {
    final days = provider.weeklyDayLabels;
    final counts = provider.weeklyFaultCounts;
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxCount + 2).toDouble();

    return _SectionCard(
      title: 'Faults - Last 7 Days',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.dividerOf(context),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 2,
                  getTitlesWidget: (value, _) => Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10, 
                      color: AppColors.textHintOf(context),
                    ),
                  ),
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index < 0 || index >= days.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      days[index],
                      style: TextStyle(
                        fontSize: 10, 
                        color: AppColors.textHintOf(context),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(counts.length, (index) {
              final isToday = index == counts.length - 1;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: counts[index].toDouble(),
                    color: isToday
                        ? AppColors.primary
                        : AppColors.primaryLight.withValues(alpha: 0.6),
                    width: 22,
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

  Widget _buildFleetList(ManagerDashboardProvider provider) {
    final preview = provider.devices.take(10).toList();
    final extra = provider.devices.length - preview.length;

    return _SectionCard(
      title: 'Device Fleet',
      child: preview.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No devices available.',
                style: TextStyle(
                  fontSize: 12, 
                  color: AppColors.textHintOf(context),
                ),
              ),
            )
          : Column(
              children: [
                ...preview.map(
                  (device) => _FleetRow(
                    device: device,
                    metric: _metricFor(device.id, provider.metrics),
                  ),
                ),
                if (extra > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.textHintOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+$extra more - open Devices tab to see all',
                        style: TextStyle(
                          fontSize: 12, 
                          color: AppColors.textHintOf(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  MetricModel? _metricFor(int deviceId, List<MetricModel> metrics) {
    try {
      return metrics.firstWhere((metric) => metric.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), 
                blurRadius: 6),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: isDark ? AppColors.primaryLight : color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.primaryLight : color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10, 
                color: AppColors.textHintOf(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), 
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11, 
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _FleetRow extends StatelessWidget {
  const _FleetRow({required this.device, this.metric});

  final DeviceModel device;
  final MetricModel? metric;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusBlue(device.status);
    final latency = metric?.latencyMs != null
        ? '${metric!.latencyMs!.toStringAsFixed(0)} ms'
        : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.dividerOf(context), 
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                Text(
                  device.location ?? device.ipAddress,
                  style: TextStyle(
                    fontSize: 11, 
                    color: AppColors.textHintOf(context),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latency,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Text(
                'latency',
                style: TextStyle(
                  fontSize: 10, 
                  color: AppColors.textHintOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _statusBlue(String status) {
  switch (status) {
    case 'online':
      return AppColors.primary;
    case 'degraded':
      return AppColors.primaryLight;
    case 'offline':
      return AppColors.primaryDark;
    default:
      return AppColors.primaryLight.withOpacity(0.6);
  }
}
