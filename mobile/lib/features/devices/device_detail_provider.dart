import 'package:flutter/material.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../data/models/alert_model.dart';
import '../../services/api_client.dart';

/// Snapshot of a single ping diagnostic run (stored for history comparison).
class DiagnosticSnapshot {
  final DateTime timestamp;
  final bool     passed;
  final double?  avgLatency;
  final double?  minLatency;
  final double?  maxLatency;
  final double   packetLossPct;
  final int      totalPings;
  final int      successPings;

  const DiagnosticSnapshot({
    required this.timestamp,
    required this.passed,
    this.avgLatency,
    this.minLatency,
    this.maxLatency,
    required this.packetLossPct,
    required this.totalPings,
    required this.successPings,
  });
}

/// DeviceDetailProvider manages all data for a single device's detail screen.
///
/// Loads:
///   - Latest metric snapshot for this device
///   - 7-day metrics history for the latency chart
///   - All alerts for this device, sorted newest-first
class DeviceDetailProvider extends ChangeNotifier {

  final DeviceModel device;

  DeviceDetailProvider({required this.device});

  // ── State ─────────────────────────────────────────────────────────────────
  bool    _isLoading    = false;
  String? _errorMessage;

  // ── Data ──────────────────────────────────────────────────────────────────
  MetricModel?      _latestMetric   = null;
  List<MetricModel> _metricsHistory = [];
  List<AlertModel>  _deviceAlerts   = [];
  final List<DiagnosticSnapshot> _diagnosticHistory = [];

  // ── Getters ───────────────────────────────────────────────────────────────
  bool    get isLoading    => _isLoading;
  bool    get hasError     => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  MetricModel?      get latestMetric   => _latestMetric;
  List<MetricModel> get metricsHistory => _metricsHistory;
  List<AlertModel>  get deviceAlerts   => _deviceAlerts;
  List<DiagnosticSnapshot> get diagnosticHistory =>
      List.unmodifiable(_diagnosticHistory);

  /// Unresolved alerts only — shown in the header warning pill and section 5.
  List<AlertModel> get activeAlerts =>
      _deviceAlerts.where((a) => !a.isResolved).toList();

  /// Estimated 7-day uptime percentage for this device.
  /// Uses the metrics history: a day counts as "up" if a metric was recorded
  /// with non-null latency (i.e. the device was reachable).
  double get deviceUptimePct {
    if (_metricsHistory.isEmpty) return 0;
    final up = _metricsHistory.where((m) => m.latencyMs != null).length;
    return (up / _metricsHistory.length) * 100;
  }

  /// Store a diagnostic snapshot. Keeps the most recent 5.
  void addDiagnosticResult(DiagnosticSnapshot snapshot) {
    _diagnosticHistory.insert(0, snapshot);
    if (_diagnosticHistory.length > 5) {
      _diagnosticHistory.removeLast();
    }
    notifyListeners();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadDeviceData() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiClient.getMetrics(deviceId: device.id),
        ApiClient.getAlerts(),
        ApiClient.getMetricHistory(device.id),
        ApiClient.getDeviceReports(device.id),
      ]);

      final allMetrics    = results[0] as List<MetricModel>;
      final allAlerts     = results[1] as List<AlertModel>;
      final historyList   = results[2] as List<MetricModel>;
      final reports       = results[3] as List<Map<String, dynamic>>;

      // Latest snapshot
      final deviceMetrics = allMetrics
          .where((m) => m.deviceId == device.id)
          .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      _latestMetric = deviceMetrics.isNotEmpty ? deviceMetrics.first : null;

      // Use real history if available, otherwise generate fallback
      _metricsHistory = historyList.isNotEmpty
          ? historyList
          : _generateMetricHistory();

      // Alerts for this device only, newest first
      _deviceAlerts = allAlerts
          .where((a) => a.deviceId == device.id)
          .toList()
          ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));

      // Convert monitoring reports to diagnostic snapshots
      _diagnosticHistory.clear();
      for (final report in reports.take(5)) {
        final snapshot = _reportToSnapshot(report);
        if (snapshot != null) {
          _diagnosticHistory.add(snapshot);
        }
      }

    } catch (e) {
      _errorMessage = 'Failed to load device data. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Convert a monitoring report JSON to a DiagnosticSnapshot.
  DiagnosticSnapshot? _reportToSnapshot(Map<String, dynamic> report) {
    try {
      final status = report['status'] as String?;
      final executedAt = report['executed_at'] as String?;
      final details = report['details'] as String? ?? '';
      
      if (executedAt == null) return null;

      // Parse latency and packet loss from details string
      // Example: "Ping OK — latency 12.3 ms, loss 0.0%"
      final latencyMatch = RegExp(r'latency\s+([\d.]+)\s*ms').firstMatch(details);
      final lossMatch = RegExp(r'loss\s+([\d.]+)\s*%').firstMatch(details);
      
      final latency = latencyMatch != null 
          ? double.tryParse(latencyMatch.group(1)!) 
          : null;
      final loss = lossMatch != null 
          ? double.tryParse(lossMatch.group(1)!) ?? 100.0
          : 100.0;

      final passed = status == 'success' && (loss <= 5.0);

      return DiagnosticSnapshot(
        timestamp: DateTime.parse(executedAt),
        passed: passed,
        avgLatency: latency,
        minLatency: latency,
        maxLatency: latency,
        packetLossPct: loss,
        totalPings: 4,
        successPings: ((4 * (100 - loss) / 100).round()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() => loadDeviceData();

  // ── History generation fallback ───────────────────────────────────────────

  /// Generates 7 daily data points when DummyData.metricHistory has no
  /// entry for this device. Values are seeded from the latest snapshot
  /// with realistic variation so the chart looks plausible.
  List<MetricModel> _generateMetricHistory() {
    final baseLatency = _latestMetric?.latencyMs    ?? 20.0;
    final baseCpu     = _latestMetric?.cpuUsagePct  ?? 30.0;
    final baseMem     = _latestMetric?.memoryUsagePct ?? 45.0;
    final now         = DateTime.now();

    return List.generate(7, (i) {
      // i=0 is 6 days ago, i=6 is today
      final daysAgo = 6 - i;

      // Latency varies ±20% with a daily pattern
      final latencyVariation = (daysAgo % 3 == 0)
          ?  baseLatency * 0.2
          : (daysAgo % 2 == 0)
              ? -baseLatency * 0.1
              :  baseLatency * 0.05;
      final latency = (baseLatency + latencyVariation).clamp(1.0, 500.0);

      // Packet loss only appears when latency is elevated
      final loss = latency > 200 ? 8.5 : latency > 100 ? 2.0 : 0.0;

      // CPU and memory also drift slightly
      final cpu = (baseCpu + (daysAgo % 4) * 3.0).clamp(5.0, 100.0);
      final mem = (baseMem + (daysAgo % 3) * 2.5).clamp(10.0, 100.0);

      return MetricModel(
        id:             1000 + i,
        deviceId:       device.id,
        latencyMs:      latency,
        packetLossPct:  loss,
        cpuUsagePct:    cpu,
        memoryUsagePct: mem,
        bandwidthInBps:  _latestMetric?.bandwidthInBps,
        bandwidthOutBps: _latestMetric?.bandwidthOutBps,
        interfaceErrors: 0,
        uptimeSeconds:   _latestMetric?.uptimeSeconds,
        pollMethod:     'icmp',
        recordedAt:     now
            .subtract(Duration(days: daysAgo))
            .toIso8601String(),
      );
    });
  }
}