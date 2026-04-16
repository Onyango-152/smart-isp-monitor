import 'package:flutter/material.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/metric_type_model.dart';
import '../../data/models/metric_threshold_model.dart';
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
  List<MetricTypeModel> _metricTypes = [];
  List<MetricThresholdModel> _thresholds = [];
  final List<DiagnosticSnapshot> _diagnosticHistory = [];

  // ── Getters ───────────────────────────────────────────────────────────────
  bool    get isLoading    => _isLoading;
  bool    get hasError     => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  MetricModel?      get latestMetric   => _latestMetric;
  List<MetricModel> get metricsHistory => _metricsHistory;
  List<AlertModel>  get deviceAlerts   => _deviceAlerts;
  List<MetricThresholdModel> get thresholds => _thresholds;
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
      // Fetch metrics and alerts in parallel
      final results = await Future.wait([
        ApiClient.getMetrics(deviceId: device.id),
        ApiClient.getAlerts(),
        ApiClient.getMetricTypes(),
        ApiClient.getMetricThresholds(deviceId: device.id),
      ]);

      final allMetrics = results[0] as List<MetricModel>;
      final allAlerts  = results[1] as List<AlertModel>;
      _metricTypes     = results[2] as List<MetricTypeModel>;
      _thresholds      = results[3] as List<MetricThresholdModel>;

      // Latest snapshot — most recently recorded metric for this device
      final deviceMetrics = allMetrics
          .where((m) => m.deviceId == device.id)
          .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      _latestMetric   = deviceMetrics.isNotEmpty ? deviceMetrics.first : null;
      _metricsHistory = deviceMetrics.length > 7
          ? deviceMetrics.sublist(0, 7)
          : deviceMetrics.isNotEmpty
              ? deviceMetrics
              : _generateMetricHistory();

      // Alerts for this device only, newest first
      _deviceAlerts = allAlerts
          .where((a) => a.deviceId == device.id)
          .toList()
          ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));

    } catch (e) {
      _errorMessage = 'Failed to load device data. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  MetricTypeModel? _metricTypeByName(String name) {
    final key = name.toLowerCase();
    for (final m in _metricTypes) {
      if (m.name.toLowerCase() == key) return m;
    }
    return null;
  }

  MetricThresholdModel? thresholdFor(String metricName) {
    final key = metricName.toLowerCase();
    for (final t in _thresholds) {
      if (t.metricName.toLowerCase() == key) return t;
    }
    return null;
  }

  Future<void> saveThreshold({
    required String metricName,
    double? warning,
    double? critical,
    bool isActive = true,
  }) async {
    final metric = _metricTypeByName(metricName);
    if (metric == null) {
      _errorMessage = 'Metric type not found for $metricName.';
      notifyListeners();
      return;
    }

    final existing = thresholdFor(metricName);
    if (existing != null) {
      await ApiClient.updateMetricThreshold(
        id: existing.id,
        warningThreshold: warning,
        criticalThreshold: critical,
        isActive: isActive,
      );
    } else {
      await ApiClient.createMetricThreshold(
        deviceId: device.id,
        metricId: metric.id,
        warningThreshold: warning,
        criticalThreshold: critical,
        isActive: isActive,
      );
    }

    _thresholds = await ApiClient.getMetricThresholds(deviceId: device.id);
    notifyListeners();
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