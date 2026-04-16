import 'package:flutter/material.dart';
import '../../data/models/device_model.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/metric_prediction_model.dart';
import '../../core/constants.dart';
import '../../data/dummy_data.dart';
import '../../services/api_client.dart';

/// DashboardProvider holds all state shown on the technician dashboard.
///
/// Three states: loading → loaded → error.
/// The dashboard screen rebuilds only the widgets that consume changed data
/// by using Consumer<DashboardProvider> at the appropriate level.
///
/// On integration day replace the DummyData calls with API calls inside
/// loadDashboard(). The provider interface stays the same — screens need
/// no changes.
class DashboardProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  // ── Data ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> _summary = {};
  List<DeviceModel> _devices = [];
  List<AlertModel> _activeAlerts = [];
  List<Map<String, dynamic>> _weeklyFaults = [];
  List<MetricPredictionModel> _predictions = [];

  // ── Getters — state ───────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;

  // ── Getters — summary numbers ─────────────────────────────────────────────
  int get totalDevices => _summary['total_devices'] ?? 0;
  int get onlineDevices => _summary['online_devices'] ?? 0;
  int get offlineDevices => _summary['offline_devices'] ?? 0;
  int get degradedDevices => _summary['degraded_devices'] ?? 0;
  int get activeAlertsCount => _summary['active_alerts'] ?? 0;
  int get criticalAlerts => _summary['critical_alerts'] ?? 0;
  int get faultsThisWeek => _summary['faults_this_week'] ?? 0;
  int get avgMttrMinutes => _summary['avg_mttr_minutes'] ?? 0;
  double get networkUptime => (_summary['network_uptime_pct'] ?? 0).toDouble();
  double get avgLatency => (_summary['avg_latency_ms'] ?? 0).toDouble();

  // ── Getters — lists ───────────────────────────────────────────────────────

  /// Full active alert list — used by the alerts tab badge count.
  List<AlertModel> get activeAlerts => _activeAlerts;

  List<MetricPredictionModel> get predictions => _predictions;

  List<MetricPredictionModel> get highRiskPredictions => _predictions
      .where((p) => p.riskLevel == 'high' || p.riskLevel == 'critical')
      .toList();

  /// Top 3 most recent unresolved alerts — shown in the dashboard preview.
  List<AlertModel> get recentAlerts {
    final sorted = [..._activeAlerts]
      ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return sorted.take(3).toList();
  }

  /// Devices sorted by urgency: offline first, degraded second, online last.
  /// Capped at 5 for the dashboard preview — device list screen shows all.
  List<DeviceModel> get devices {
    final sorted = [..._devices]..sort((a, b) {
        int statusPriority(String status) {
          if (status == AppConstants.statusOffline) return 0;
          if (status == AppConstants.statusDegraded) return 1;
          return 2;
        }

        return statusPriority(a.status).compareTo(statusPriority(b.status));
      });
    return sorted.take(5).toList();
  }

  /// Priority queue of devices that need attention: offline or degraded only.
  /// Ranked by: offline first, then degraded+critical, degraded+high,
  /// degraded alone. Each entry pairs a device with its top alert (if any).
  List<({DeviceModel device, AlertModel? topAlert})> get needsAttention {
    final nonOnline =
        _devices.where((d) => d.status != AppConstants.statusOnline).toList();

    // Build alert lookup: deviceId → highest severity active alert
    final Map<int, AlertModel> topAlertByDevice = {};
    for (final alert in _activeAlerts) {
      final existing = topAlertByDevice[alert.deviceId];
      if (existing == null ||
          _sevRank(alert.severity) < _sevRank(existing.severity)) {
        topAlertByDevice[alert.deviceId] = alert;
      }
    }

    nonOnline.sort((a, b) {
      final pa = _attentionScore(a.status, topAlertByDevice[a.id]);
      final pb = _attentionScore(b.status, topAlertByDevice[b.id]);
      return pa.compareTo(pb);
    });

    return nonOnline
        .take(6)
        .map((d) => (device: d, topAlert: topAlertByDevice[d.id]))
        .toList();
  }

  static int _sevRank(String severity) {
    switch (severity) {
      case AppConstants.severityCritical:
        return 0;
      case AppConstants.severityHigh:
        return 1;
      case AppConstants.severityMedium:
        return 2;
      case AppConstants.severityLow:
        return 3;
      default:
        return 4;
    }
  }

  static int _attentionScore(String status, AlertModel? topAlert) {
    // Offline devices always first
    if (status == AppConstants.statusOffline) return 0;
    // Degraded + critical alert
    if (topAlert != null &&
        topAlert.severity == AppConstants.severityCritical) {
      return 1;
    }
    // Degraded + high alert
    if (topAlert != null && topAlert.severity == AppConstants.severityHigh) {
      return 2;
    }
    // Degraded + medium/low alert
    if (topAlert != null) {
      return 3;
    }
    // Degraded, no alerts
    return 4;
  }

  /// All devices — used by device list screen via DeviceProvider,
  /// but also available here if needed.
  List<DeviceModel> get allDevices => _devices;

  /// 7-day daily fault count array for the bar chart.
  /// Each entry: { 'date': String, 'faults': int, 'isToday': bool }
  List<Map<String, dynamic>> get weeklyFaults => _weeklyFaults;

  // ── MTTR (Mean Time to Resolve) ───────────────────────────────────────────

  /// Average MTTR (in minutes) for all resolved alerts.
  double get mttrMinutes {
    final resolved =
        _activeAlerts.where((a) => a.isResolved && a.resolvedAt != null);
    if (resolved.isEmpty) return avgMttrMinutes.toDouble();
    final totalMin = resolved.fold<double>(0, (sum, a) {
      final diff = DateTime.parse(a.resolvedAt!)
          .difference(DateTime.parse(a.triggeredAt));
      return sum + diff.inMinutes;
    });
    return totalMin / resolved.length;
  }

  /// MTTR trend vs prior week. Returns positive for improvement (faster),
  /// negative for regression. Currently uses last-week dummy comparison.
  double get mttrTrendPct {
    final current = mttrMinutes;
    final previous = (avgMttrMinutes > 0) ? avgMttrMinutes.toDouble() : current;
    if (previous == 0) return 0;
    return ((previous - current) / previous) * 100; // positive = improved
  }

  // ── Alert Velocity ────────────────────────────────────────────────────────

  /// Number of new alerts triggered in the last hour.
  int get alertsLastHour {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    return _activeAlerts
        .where((a) => DateTime.parse(a.triggeredAt).isAfter(cutoff))
        .length;
  }

  /// Average alerts per hour over the last 24 h.
  double get avgAlertsPerHour => _activeAlerts.length / 24;

  /// True when alertsLastHour is above the 24-h average.
  bool get alertVelocityHigh => alertsLastHour > avgAlertsPerHour;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Loads all dashboard data.
  /// Called on first render and on pull-to-refresh.
  ///
  /// On integration day replace DummyData calls with:
  ///   final response = await ApiService.get(AppConstants.dashboardEndpoint);
  ///   _summary = response.data;
  ///   final devResponse = await ApiService.get(AppConstants.devicesEndpoint);
  ///   _devices = (devResponse.data['results'] as List)
  ///       .map((j) => DeviceModel.fromJson(j)).toList();
  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiClient.getDashboardSummary(),
        ApiClient.getDevices(),
        ApiClient.getAlerts(),
        ApiClient.getMetricPredictions(),
      ]);

      _summary = results[0] as Map<String, dynamic>;
      _devices = results[1] as List<DeviceModel>;
      final allAlerts = results[2] as List<AlertModel>;
      _predictions = results[3] as List<MetricPredictionModel>;
      _activeAlerts = allAlerts.where((a) => !a.isResolved).toList();

      // Build weekly fault counts from alert data
      final now = DateTime.now();
      _weeklyFaults = List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        final label =
            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
        final count = allAlerts.where((a) {
          final d = DateTime.tryParse(a.triggeredAt);
          return d != null &&
              d.year == day.year &&
              d.month == day.month &&
              d.day == day.day;
        }).length;
        return {'date': label, 'faults': count, 'isToday': i == 6};
      });

      _lastUpdated = DateTime.now();
    } catch (e) {
      // Fallback to local demo data when backend/auth is unavailable.
      _summary = Map<String, dynamic>.from(DummyData.dashboardSummary);
      _devices = List<DeviceModel>.from(DummyData.devices);
      final allAlerts = List<AlertModel>.from(DummyData.alerts);
      _predictions = List<MetricPredictionModel>.from(DummyData.metricPredictions);
      _activeAlerts = allAlerts.where((a) => !a.isResolved).toList();

      final now = DateTime.now();
      _weeklyFaults = List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        final label =
            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
        final count = allAlerts.where((a) {
          final d = DateTime.tryParse(a.triggeredAt);
          return d != null &&
              d.year == day.year &&
              d.month == day.month &&
              d.day == day.day;
        }).length;
        return {'date': label, 'faults': count, 'isToday': i == 6};
      });

      _lastUpdated = DateTime.now();
      _errorMessage = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Pull-to-refresh handler.
  Future<void> refresh() => loadDashboard();
}
