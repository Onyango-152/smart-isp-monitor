import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../data/models/alert_model.dart';

/// DeviceDetailProvider manages all data for a single device's
/// detail screen. It loads the device's metrics history and
/// active alerts, and exposes them to the screen.
class DeviceDetailProvider extends ChangeNotifier {

  final DeviceModel device;

  DeviceDetailProvider({required this.device});

  bool    _isLoading    = false;
  String? _errorMessage;

  MetricModel?       _latestMetric;
  List<MetricModel>  _metricsHistory = [];
  List<AlertModel>   _deviceAlerts   = [];

  bool    get isLoading      => _isLoading;
  String? get errorMessage   => _errorMessage;
  MetricModel?       get latestMetric   => _latestMetric;
  List<MetricModel>  get metricsHistory => _metricsHistory;
  List<AlertModel>   get deviceAlerts   => _deviceAlerts;
  List<AlertModel>   get activeAlerts   =>
      _deviceAlerts.where((a) => !a.isResolved).toList();

  Future<void> loadDeviceData() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    try {
      // Null safety check for DummyData collections
      if (DummyData.latestMetrics.isEmpty) {
        print('DEBUG: DummyData.latestMetrics is empty');
      }

      // Latest metric snapshot for this device
      _latestMetric = null;
      if (DummyData.latestMetrics.isNotEmpty) {
        final metrics = DummyData.latestMetrics
            .where((m) => m.deviceId == device.id)
            .toList();
        if (metrics.isNotEmpty) {
          _latestMetric = metrics.first;
        }
      }

      // Generate a simulated 24-hour history of latency readings
      // so the chart has data to display.
      // On integration day this calls GET /api/metrics/device/{id}/
      _metricsHistory = _generateMetricHistory();

      // Alerts for this specific device
      _deviceAlerts = [];
      if (DummyData.alerts.isNotEmpty) {
        _deviceAlerts = DummyData.alerts
            .where((a) => a.deviceId == device.id)
            .toList();
      }

      print('DEBUG: Loaded device data successfully. Device ID: ${device.id}, '
          'Metrics: ${_metricsHistory.length}, Alerts: ${_deviceAlerts.length}');

    } catch (e, stackTrace) {
      print('ERROR in loadDeviceData: $e');
      print('Stack trace: $stackTrace');
      _errorMessage = 'Failed to load device data. Error: $e';
      _metricsHistory = [];
      _deviceAlerts = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Generates 24 hours of simulated metric data points for the chart.
  /// Each point is one hour apart. The values are seeded from the
  /// latest metric to look realistic and continuous.
  List<MetricModel> _generateMetricHistory() {
    try {
      final base    = _latestMetric?.latencyMs ?? 20.0;
      final now     = DateTime.now();
      final history = <MetricModel>[];

      for (int i = 23; i >= 0; i--) {
        try {
          // Add some realistic random variation around the base value
          final variation = (i % 3 == 0) ? 15.0 : (i % 2 == 0) ? -5.0 : 8.0;
          final latency   = (base + variation).clamp(1.0, 500.0);
          final loss      = latency > 200 ? 8.5 : latency > 100 ? 2.0 : 0.0;

          history.add(MetricModel(
            id:             i,
            deviceId:       device.id,
            latencyMs:      latency,
            packetLossPct:  loss,
            cpuUsagePct:    _latestMetric?.cpuUsagePct,
            memoryUsagePct: _latestMetric?.memoryUsagePct,
            pollMethod:     'icmp',
            recordedAt:     now.subtract(Duration(hours: i)).toIso8601String(),
          ));
        } catch (e) {
          print('ERROR generating metric for hour $i: $e');
          // Continue with next iteration
          continue;
        }
      }
      print('DEBUG: Generated ${history.length} metric history entries');
      return history;
    } catch (e) {
      print('ERROR in _generateMetricHistory: $e');
      return [];
    }
  }

  Future<void> refresh() => loadDeviceData();
}