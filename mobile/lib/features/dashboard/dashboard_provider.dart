import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';
import '../../data/models/device_model.dart';
import '../../data/models/alert_model.dart';

/// DashboardProvider holds all the data shown on the technician dashboard.
/// It has three states — loading, loaded, and error — which the screen
/// uses to show the appropriate UI at each stage.
class DashboardProvider extends ChangeNotifier {

  // ── State ────────────────────────────────────────────────────────────────
  bool    _isLoading    = false;
  String? _errorMessage;

  // ── Data ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> _summary = {};
  List<DeviceModel>    _devices = [];
  List<AlertModel>     _activeAlerts = [];

  // ── Getters ───────────────────────────────────────────────────────────────
  bool                 get isLoading    => _isLoading;
  String?              get errorMessage => _errorMessage;
  Map<String, dynamic> get summary      => _summary;
  List<DeviceModel>    get devices      => _devices;
  List<AlertModel>     get activeAlerts => _activeAlerts;

  // Derived values computed from summary data
  int    get totalDevices    => _summary['total_devices']    ?? 0;
  int    get onlineDevices   => _summary['online_devices']   ?? 0;
  int    get offlineDevices  => _summary['offline_devices']  ?? 0;
  int    get degradedDevices => _summary['degraded_devices'] ?? 0;
  int    get activeAlertsCount => _summary['active_alerts']  ?? 0;
  int    get criticalAlerts  => _summary['critical_alerts']  ?? 0;
  double get networkUptime   => (_summary['network_uptime_pct'] ?? 0).toDouble();
  double get avgLatency      => (_summary['avg_latency_ms']     ?? 0).toDouble();

  /// loadDashboard is called when the dashboard screen first appears.
  /// It simulates a network request with a short delay, then populates
  /// all the data fields and notifies listeners to rebuild the screen.
  Future<void> loadDashboard() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate network delay — remove this when using real API
      await Future.delayed(const Duration(milliseconds: 800));

      // Load dummy data — replace these with API calls on integration day
      _summary      = DummyData.dashboardSummary;
      _devices      = DummyData.devices;
      _activeAlerts = DummyData.alerts
          .where((a) => !a.isResolved)
          .toList();

    } catch (e) {
      _errorMessage = 'Failed to load dashboard. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// refresh is called when the user pulls down to refresh.
  Future<void> refresh() async {
    await loadDashboard();
  }
}