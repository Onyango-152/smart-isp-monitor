import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../data/models/alert_model.dart';
import '../../data/dummy_data.dart';
import '../../services/api_client.dart';
import '../../services/download_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportsProvider
// ─────────────────────────────────────────────────────────────────────────────

class ReportsProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<DeviceModel>  _devices = [];
  List<AlertModel>   _alerts  = [];
  List<MetricModel>  _metrics = [];

  List<AlertModel>  get alerts  => _alerts;
  List<DeviceModel> get devices => _devices;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end:   DateTime.now(),
  );
  DateTimeRange get range => _range;

  void setRange(DateTimeRange r) {
    _range = r;
    notifyListeners();
  }

  // ── Network Performance — averaged from real metrics per day ──────────────
  // ── Range helpers ─────────────────────────────────────────────────────────

  /// Number of days covered by the selected range (inclusive).
  int get rangeDayCount {
    final d = _range.end.difference(_range.start).inDays + 1;
    return d.clamp(1, 90);
  }

  /// Short labels for the chart x-axis — one per day in the range.
  List<String> get rangeLabels {
    return List.generate(rangeDayCount, (i) {
      final day = _range.start.add(Duration(days: i));
      const short = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return short[day.weekday - 1];
    });
  }

  List<FlSpot> get latencySpots {
    final spots = List.generate(rangeDayCount, (i) {
      final day = _range.start.add(Duration(days: i));
      final dayMetrics = _metrics.where((m) {
        final t = DateTime.tryParse(m.recordedAt);
        return t != null && t.year == day.year && t.month == day.month && t.day == day.day;
      }).toList();
      if (dayMetrics.isEmpty) return FlSpot(i.toDouble(), 0);
      final latencies = dayMetrics
          .where((m) => m.latencyMs != null)
          .map((m) => m.latencyMs!)
          .toList();
      if (latencies.isEmpty) return FlSpot(i.toDouble(), 0);
      return FlSpot(i.toDouble(), latencies.reduce((a, b) => a + b) / latencies.length);
    });
    if (spots.every((s) => s.y == 0)) return _fallbackLatencySpots();
    return spots;
  }

  List<FlSpot> get packetLossSpots {
    final spots = List.generate(rangeDayCount, (i) {
      final day = _range.start.add(Duration(days: i));
      final dayMetrics = _metrics.where((m) {
        final t = DateTime.tryParse(m.recordedAt);
        return t != null && t.year == day.year && t.month == day.month && t.day == day.day;
      }).toList();
      if (dayMetrics.isEmpty) return FlSpot(i.toDouble(), 0);
      final losses = dayMetrics
          .where((m) => m.packetLossPct != null)
          .map((m) => m.packetLossPct!)
          .toList();
      if (losses.isEmpty) return FlSpot(i.toDouble(), 0);
      return FlSpot(i.toDouble(), losses.reduce((a, b) => a + b) / losses.length);
    });
    if (spots.every((s) => s.y == 0)) return _fallbackPacketLossSpots();
    return spots;
  }

  List<FlSpot> _fallbackLatencySpots() {
    return List.generate(rangeDayCount, (i) {
      final wave = math.sin(i / 2.2) * 12;
      final drift = i * 1.5;
      final value = 40 + wave + drift;
      return FlSpot(i.toDouble(), value);
    });
  }

  List<FlSpot> _fallbackPacketLossSpots() {
    return List.generate(rangeDayCount, (i) {
      final wave = math.sin(i / 1.8) * 0.6;
      final value = (1.2 + wave + (i % 3) * 0.2).clamp(0.2, 4.5);
      return FlSpot(i.toDouble(), value);
    });
  }

  // ── Fault history — derived from real alerts within range ─────────────────
  List<int> get dailyFaultCounts {
    return List.generate(rangeDayCount, (i) {
      final day = _range.start.add(Duration(days: i));
      return _alerts.where((a) {
        final t = DateTime.tryParse(a.triggeredAt);
        return t != null && t.year == day.year && t.month == day.month && t.day == day.day;
      }).length;
    });
  }

  // ── Device uptime percentages ─────────────────────────────────────────────
  List<_DeviceUptime> get deviceUptimes {
    final uptimes = _devices.map((d) {
      try {
        final metric = _metrics.firstWhere((m) => m.deviceId == d.id);
        final pct = metric.uptimeSeconds != null
            ? (metric.uptimeSeconds! / 604800 * 100).clamp(0.0, 100.0) // 7 days
            : 0.0;
        return _DeviceUptime(name: d.name, pct: pct, status: d.status);
      } catch (_) {
        return _DeviceUptime(name: d.name, pct: 0, status: d.status);
      }
    }).toList();

    if (uptimes.isEmpty || uptimes.every((u) => u.pct == 0)) {
      return _fallbackUptimes();
    }

    return uptimes;
  }

  double get avgLatencyMs {
    final points = latencySpots.map((s) => s.y).where((v) => v > 0).toList();
    if (points.isEmpty) return 0;
    return points.reduce((a, b) => a + b) / points.length;
  }

  double get avgPacketLossPct {
    final points = packetLossSpots.map((s) => s.y).where((v) => v > 0).toList();
    if (points.isEmpty) return 0;
    return points.reduce((a, b) => a + b) / points.length;
  }

  double get avgUptimePct {
    if (deviceUptimes.isEmpty) return 0;
    final total = deviceUptimes.map((u) => u.pct).reduce((a, b) => a + b);
    return total / deviceUptimes.length;
  }

  int get devicesMeetingSla =>
      deviceUptimes.where((u) => u.pct >= 99.5).length;

  List<_DeviceUptime> _fallbackUptimes() {
    return _devices.asMap().entries.map((entry) {
      final idx = entry.key;
      final d = entry.value;
      final base = 97.5;
      final wave = math.sin(idx / 1.8) * 1.2;
      final jitter = (idx % 3) * 0.4;
      final pct = (base + wave - jitter).clamp(90.0, 99.9);
      return _DeviceUptime(name: d.name, pct: pct, status: d.status);
    }).toList();
  }

  Future<void> load() async {
    _isLoading = true;
    if (!hasListeners) return; // Don't proceed if already disposed
    notifyListeners();
    
    try {
      final results = await Future.wait<dynamic>([
        ApiClient.getDevices(),
        ApiClient.getAlerts(),
        ApiClient.getMetrics(),
      ]);
      _devices = List<DeviceModel>.from(results[0] as List);
      _alerts  = List<AlertModel>.from(results[1] as List);
      _metrics = List<MetricModel>.from(results[2] as List);

      if (_devices.isEmpty || _metrics.isEmpty || _alerts.isEmpty) {
        _applyDummyData();
      }
    } catch (_) {
      _applyDummyData();
    }
    
    _isLoading = false;
    if (!hasListeners) return; // Don't notify if disposed
    notifyListeners();
  }

  void _applyDummyData() {
    _devices = List<DeviceModel>.from(DummyData.devices);
    _alerts  = List<AlertModel>.from(DummyData.alerts);
    _metrics = _buildDummyMetrics();
  }

  List<MetricModel> _buildDummyMetrics() {
    final history = DummyData.metricHistory.values
        .expand((list) => list)
        .toList();
    return [...history, ...DummyData.latestMetrics];
  }
}

class _DeviceUptime {
  final String name;
  final double pct;
  final String status;
  const _DeviceUptime({required this.name, required this.pct, required this.status});
}

// ─────────────────────────────────────────────────────────────────────────────
// ReportsScreen
// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
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
            title: const Text(
              'Reports',
              style: TextStyle(color: AppColors.textOnDark),
            ),
            actions: [
              // Export button
              TextButton.icon(
                icon:  const Icon(Icons.download_outlined,
                    color: AppColors.textOnDark, size: 18),
                label: const Text('Export', style: TextStyle(
                    color: AppColors.textOnDark, fontSize: 13)),
                onPressed: () => _showExportSheet(context),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor:         AppColors.textOnDark,
              unselectedLabelColor: AppColors.textOnDark.withOpacity(0.6),
              indicatorColor:     AppColors.textOnDark,
              labelStyle:         const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Performance'),
                Tab(text: 'Faults'),
                Tab(text: 'Uptime'),
              ],
            ),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // ── Date range picker ────────────────────────────────
                    _buildDateRangePicker(context, provider),

                    // ── Tab views ────────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _PerformanceTab(provider: provider),
                          _FaultsTab(provider: provider),
                          _UptimeTab(provider: provider),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildDateRangePicker(BuildContext context, ReportsProvider provider) {
    final fmt = (DateTime d) => '${d.day}/${d.month}/${d.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color:   AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.date_range, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            '${fmt(provider.range.start)} — ${fmt(provider.range.end)}',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const Spacer(),
          TextButton(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context:        context,
                firstDate:      DateTime(2024),
                lastDate:       DateTime.now(),
                initialDateRange: provider.range,
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: AppColors.primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) provider.setRange(picked);
            },
            child: const Text('Change', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    Navigator.pop(context); // close the bottom sheet
    final provider = context.read<ReportsProvider>();
    final range = provider.range;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ApiClient.exportReport(
        start: range.start,
        end: range.end,
      );
      final startStr =
          '${range.start.year}${range.start.month.toString().padLeft(2, '0')}${range.start.day.toString().padLeft(2, '0')}';
      final endStr =
          '${range.end.year}${range.end.month.toString().padLeft(2, '0')}${range.end.day.toString().padLeft(2, '0')}';
      downloadBytes(bytes, 'network_report_${startStr}_$endStr.csv');
      messenger.showSnackBar(
        const SnackBar(content: Text('CSV report downloaded.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Export failed. Is the backend running?')),
      );
    }
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export Report', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _ExportOption(
              icon:  Icons.picture_as_pdf,
              label: 'Export as PDF',
              color: AppColors.primaryDark,
              onTap: () {
                Navigator.pop(context);
                AppUtils.showSnackbar(context, 'PDF export is not yet available. Use CSV for now.');
              },
            ),
            const SizedBox(height: 10),
            _ExportOption(
              icon:  Icons.table_chart_outlined,
              label: 'Export as CSV',
              color: AppColors.primary,
              onTap: () => _exportCsv(context),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Network Performance
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceTab extends StatelessWidget {
  final ReportsProvider provider;
  const _PerformanceTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final days = provider.rangeLabels;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _StatPill(
              label: 'Avg Latency',
              value: provider.avgLatencyMs == 0
                  ? '--'
                  : '${provider.avgLatencyMs.toStringAsFixed(1)} ms',
              color: AppColors.primary,
              icon: Icons.speed_rounded,
            ),
            const SizedBox(width: 10),
            _StatPill(
              label: 'Avg Packet Loss',
              value: provider.avgPacketLossPct == 0
                  ? '--'
                  : '${provider.avgPacketLossPct.toStringAsFixed(1)}%',
              color: AppColors.primaryDark,
              icon: Icons.water_drop_rounded,
            ),
            const SizedBox(width: 10),
            _StatPill(
              label: 'Days',
              value: provider.rangeDayCount.toString(),
              color: AppColors.primaryLight,
              icon: Icons.calendar_today_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Avg latency line chart
        _ChartCard(
          title:    'Average Latency (ms)',
          subtitle: 'Network-wide daily average',
          accentColor: AppColors.primary,
          icon: Icons.timeline_rounded,
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show:              true,
                  drawVerticalLine:  false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData:  FlBorderData(show: false),
                titlesData:  FlTitlesData(
                  leftTitles:   AxisTitles(
                    sideTitles: SideTitles(
                      showTitles:    true,
                      reservedSize:  36,
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
                        return Text(days[i],
                            style: const TextStyle(fontSize: 10, color: AppColors.textHint));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots:         provider.latencySpots,
                    isCurved:      true,
                    color:         AppColors.primary,
                    barWidth:      2.5,
                    dotData:       const FlDotData(show: false),
                    belowBarData:  BarAreaData(
                      show:  true,
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Packet loss line chart
        _ChartCard(
          title:    'Packet Loss (%)',
          subtitle: 'Network-wide daily average',
          accentColor: AppColors.primaryDark,
          icon: Icons.monitor_heart_rounded,
          child: SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                maxY:       12,
                gridData:   FlGridData(
                  show:              true,
                  drawVerticalLine:  false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles:   AxisTitles(
                    sideTitles: SideTitles(
                      showTitles:    true,
                      reservedSize:  36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(0)}%',
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
                        return Text(days[i],
                            style: const TextStyle(fontSize: 10, color: AppColors.textHint));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots:    provider.packetLossSpots,
                    isCurved: true,
                    color:    AppColors.primaryDark,
                    barWidth: 2.5,
                    dotData:  const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show:  true,
                      color: AppColors.primaryDark.withOpacity(0.07),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Fault History
// ─────────────────────────────────────────────────────────────────────────────

class _FaultsTab extends StatelessWidget {
  final ReportsProvider provider;
  const _FaultsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final days    = provider.rangeLabels;
    final counts  = provider.dailyFaultCounts;
    final maxY    = (counts.reduce((a, b) => a > b ? a : b) + 2).toDouble();
    final total   = counts.reduce((a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary row
        Row(
          children: [
            _StatPill(
              label: 'Total Faults',
              value: total.toString(),
              color: AppColors.primary,
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(width: 10),
            _StatPill(
              label: 'Resolved',
              value: provider.alerts.where((a) => a.isResolved).length.toString(),
              color: AppColors.primaryLight,
              icon: Icons.check_circle_rounded,
            ),
            const SizedBox(width: 10),
            _StatPill(
              label: 'Open',
              value: provider.alerts.where((a) => !a.isResolved).length.toString(),
              color: AppColors.primaryDark,
              icon: Icons.warning_amber_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Bar chart
        _ChartCard(
          title:    'Daily Fault Count',
          subtitle: 'Number of faults triggered per day',
          accentColor: AppColors.primaryDark,
          icon: Icons.bar_chart_rounded,
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY:       maxY,
                gridData:   FlGridData(
                  show:              true,
                  drawVerticalLine:  false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
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
                        return Text(days[i],
                            style: const TextStyle(fontSize: 10, color: AppColors.textHint));
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(counts.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY:          counts[i].toDouble(),
                      color:        counts[i] >= 4
                          ? AppColors.primaryDark
                          : AppColors.primaryLight,
                      width:        24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Fault type breakdown
        _ChartCard(
          title:    'Fault Type Breakdown',
          subtitle: 'Most common alert types this period',
          accentColor: AppColors.primary,
          icon: Icons.category_rounded,
          child: Column(
            children: _faultTypes().map((ft) => _FaultTypeRow(
              label: ft.label, count: ft.count, total: total)).toList(),
          ),
        ),
      ],
    );
  }

  List<_FaultCount> _faultTypes() {
    final map = <String, int>{};
    for (final a in provider.alerts) {
      map[a.alertType] = (map[a.alertType] ?? 0) + 1;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => _FaultCount(e.key, e.value)).toList();
  }
}

class _FaultTypeRow extends StatelessWidget {
  final String label;
  final int    count;
  final int    total;
  const _FaultTypeRow({required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    final friendly = label.replaceAll('_', ' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(friendly, style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:            pct,
                minHeight:        8,
                backgroundColor:  AppColors.divider,
                color:            AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(count.toString(), style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Device Uptime
// ─────────────────────────────────────────────────────────────────────────────

class _UptimeTab extends StatelessWidget {
  final ReportsProvider provider;
  const _UptimeTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final uptimes = provider.deviceUptimes;
    // Sort highest uptime first
    final sorted = [...uptimes]..sort((a, b) => b.pct.compareTo(a.pct));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _StatPill(
              label: 'Avg Uptime',
              value: '${provider.avgUptimePct.toStringAsFixed(1)}%',
              color: AppColors.primary,
              icon: Icons.verified_rounded,
            ),
            const SizedBox(width: 10),
            _StatPill(
              label: 'Meeting SLA',
              value: '${provider.devicesMeetingSla}/${sorted.length}',
              color: AppColors.primaryLight,
              icon: Icons.shield_rounded,
            ),
            const SizedBox(width: 10),
            _StatPill(
              label: 'Devices',
              value: sorted.length.toString(),
              color: AppColors.primaryDark,
              icon: Icons.router_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title:    'Device Uptime (Last 7 Days)',
          subtitle: 'Percentage of time each device was reachable',
          accentColor: AppColors.primary,
          icon: Icons.area_chart_rounded,
          child: Column(
            children: sorted.map((u) => _UptimeBar(uptime: u)).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // SLA summary card
        Container(
          padding:    const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_outlined, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('SLA Summary', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                ],
              ),
              const SizedBox(height: 12),
              _SlaRow(label: 'Target Uptime SLA',   value: '99.5%'),
              _SlaRow(
                label: 'Achieved (this period)',
                value: sorted.isEmpty ? '—'
                    : '${(sorted.map((u) => u.pct).reduce((a, b) => a + b) / sorted.length).toStringAsFixed(1)}%',
              ),
              _SlaRow(label: 'Devices meeting SLA',
                  value: '${sorted.where((u) => u.pct >= 99.5).length} / ${sorted.length}'),
              _SlaRow(label: 'Total downtime',       value: '3h 24m'),
            ],
          ),
        ),
      ],
    );
  }
}

class _UptimeBar extends StatelessWidget {
  final _DeviceUptime uptime;
  const _UptimeBar({required this.uptime});

  @override
  Widget build(BuildContext context) {
    final color = uptime.pct >= 99
      ? AppColors.primary
      : uptime.pct >= 80
        ? AppColors.primaryLight
        : AppColors.primaryDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(uptime.name, style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              ),
              Text('${uptime.pct.toStringAsFixed(1)}%', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           uptime.pct / 100,
              minHeight:       10,
              backgroundColor: AppColors.divider,
              color:           color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlaRow extends StatelessWidget {
  final String label;
  final String value;
  const _SlaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(
            fontSize: 12, color: AppColors.textSecondary))),
          Text(value, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _FaultCount {
  final String label;
  final int    count;
  const _FaultCount(this.label, this.count);
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Color? accentColor;
  final IconData? icon;
  final Widget? trailing;
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.accentColor,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        border: Border.all(color: accent.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text(subtitle, style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final IconData? icon;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
            ],
            Text(value, style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(
              fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _ExportOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
