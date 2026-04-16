import '../core/constants.dart';
import 'models/device_model.dart';
import 'models/metric_model.dart';
import 'models/metric_prediction_model.dart';
import 'models/alert_model.dart';
import 'models/report_model.dart';
import 'models/user_model.dart';
import 'models/task_model.dart';

/// DummyData provides realistic hardcoded data for every screen.
///
/// On integration day, each provider swaps these static lists for
/// real API calls. The data shapes exactly match Django API responses.
///
/// Timestamps use [_ago] helpers so relative labels like "2h ago"
/// stay accurate regardless of when the app is run.
class DummyData {
  DummyData._();

  // ── Timestamp helpers ─────────────────────────────────────────────────────

  /// Returns an ISO 8601 string [minutes] minutes before now.
  static String _ago({int days = 0, int hours = 0, int minutes = 0}) {
    final dt = DateTime.now().toUtc().subtract(Duration(
      days:    days,
      hours:   hours,
      minutes: minutes,
    ));
    return dt.toIso8601String();
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  static final UserModel technicianUser = UserModel(
    id:         1,
    email:      'technician@isp.co.ke',
    username:   'John Kamau',
    role:       AppConstants.roleTechnician,
    isActive:   true,
    dateJoined: _ago(days: 365),
    lastLogin:  _ago(hours: 1),
  );

  static final UserModel managerUser = UserModel(
    id:         2,
    email:      'manager@isp.co.ke',
    username:   'Grace Wanjiru',
    role:       AppConstants.roleManager,
    isActive:   true,
    dateJoined: _ago(days: 400),
    lastLogin:  _ago(hours: 2),
  );

  static final UserModel customerUser = UserModel(
    id:         3,
    email:      'customer@isp.co.ke',
    username:   'Peter Otieno',
    role:       AppConstants.roleCustomer,
    isActive:   true,
    dateJoined: _ago(days: 200),
    lastLogin:  _ago(hours: 6),
  );

  // ── Clients (customer accounts managed by the technician) ─────────────────
  // Each client is a UserModel with role='customer'. The assignedDeviceIds
  // are tracked in a parallel map below.

  static final List<UserModel> clients = [
    customerUser, // Peter Otieno — id 3
    UserModel(
      id:         10,
      email:      'alice.muthoni@gmail.com',
      username:   'Alice Muthoni',
      role:       AppConstants.roleCustomer,
      isActive:   true,
      dateJoined: _ago(days: 310),
      lastLogin:  _ago(hours: 2),
    ),
    UserModel(
      id:         11,
      email:      'brian.kipchoge@yahoo.com',
      username:   'Brian Kipchoge',
      role:       AppConstants.roleCustomer,
      isActive:   true,
      dateJoined: _ago(days: 240),
      lastLogin:  _ago(hours: 5),
    ),
    UserModel(
      id:         12,
      email:      'catherine.njeri@isp.co.ke',
      username:   'Catherine Njeri',
      role:       AppConstants.roleCustomer,
      isActive:   true,
      dateJoined: _ago(days: 180),
      lastLogin:  _ago(minutes: 45),
    ),
    UserModel(
      id:         13,
      email:      'daniel.oduor@outlook.com',
      username:   'Daniel Oduor',
      role:       AppConstants.roleCustomer,
      isActive:   false,
      dateJoined: _ago(days: 400),
      lastLogin:  _ago(days: 30),
    ),
    UserModel(
      id:         14,
      email:      'esther.wambui@gmail.com',
      username:   'Esther Wambui',
      role:       AppConstants.roleCustomer,
      isActive:   true,
      dateJoined: _ago(days: 120),
      lastLogin:  _ago(hours: 1),
    ),
    UserModel(
      id:         15,
      email:      'felix.maina@isp.co.ke',
      username:   'Felix Maina',
      role:       AppConstants.roleCustomer,
      isActive:   true,
      dateJoined: _ago(days: 90),
      lastLogin:  _ago(hours: 8),
    ),
    UserModel(
      id:         16,
      email:      'grace.akinyi@yahoo.com',
      username:   'Grace Akinyi',
      role:       AppConstants.roleCustomer,
      isActive:   false,
      dateJoined: _ago(days: 350),
      lastLogin:  _ago(days: 15),
    ),
    UserModel(
      id:         17,
      email:      'henry.mutiso@gmail.com',
      username:   'Henry Mutiso',
      role:       AppConstants.roleCustomer,
      isActive:   true,
      dateJoined: _ago(days: 60),
      lastLogin:  _ago(hours: 12),
    ),
    UserModel(
      id:         18,
      email:      'irene.chebet@isp.co.ke',
      username:   'Irene Chebet',
      role:       AppConstants.roleCustomer,
      isActive:   true,
      dateJoined: _ago(days: 150),
      lastLogin:  _ago(hours: 3),
    ),
  ];

  /// Maps client user IDs → list of device IDs they are subscribed to.
  static final Map<int, List<int>> clientDevices = {
    3:  [1, 4],       // Peter Otieno → Core Router, AP-Rooftop
    10: [2, 6],       // Alice Muthoni → Switch A, Switch B
    11: [3],          // Brian Kipchoge → OLT-01
    12: [1, 7],       // Catherine Njeri → Core Router, OLT-02
    13: [5],          // Daniel Oduor → Backup Router (inactive client)
    14: [8, 2],       // Esther Wambui → AP-Block C, Switch A
    15: [7, 1],       // Felix Maina → OLT-02, Core Router
    16: [3, 4],       // Grace Akinyi → OLT-01, AP-Rooftop (inactive)
    17: [6],          // Henry Mutiso → Switch B
    18: [1, 3, 8],    // Irene Chebet → Core Router, OLT-01, AP-Block C
  };

  /// Subscription plan names per client.
  static final Map<int, String> clientPlans = {
    3:  'Business Pro',
    10: 'Home Basic',
    11: 'Home Premium',
    12: 'Business Pro',
    13: 'Home Basic',
    14: 'Home Premium',
    15: 'Business Enterprise',
    16: 'Home Basic',
    17: 'Home Basic',
    18: 'Business Pro',
  };

  // ── Devices ───────────────────────────────────────────────────────────────
  // 8 devices — enough to test search, filter, scroll, and all status states.

  static final List<DeviceModel> devices = [
    DeviceModel(
      id:            1,
      name:          'Core Router',
      ipAddress:     '192.168.1.1',
      macAddress:    'AA:BB:CC:DD:EE:01',
      deviceType:    AppConstants.deviceRouter,
      status:        AppConstants.statusOnline,
      location:      'Server Room',
      description:   'Main core router connecting upstream ISP link',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      _ago(minutes: 5),
      createdAt:     _ago(days: 365),
    ),
    DeviceModel(
      id:            2,
      name:          'Access Switch A',
      ipAddress:     '192.168.1.10',
      macAddress:    'AA:BB:CC:DD:EE:02',
      deviceType:    AppConstants.deviceSwitch,
      status:        AppConstants.statusOnline,
      location:      'Distribution Cabinet — Block A',
      description:   '24-port managed switch serving Block A customers',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      _ago(minutes: 5),
      createdAt:     _ago(days: 365),
    ),
    DeviceModel(
      id:            3,
      name:          'OLT-01',
      ipAddress:     '192.168.1.20',
      macAddress:    'AA:BB:CC:DD:EE:03',
      deviceType:    AppConstants.deviceOlt,
      status:        AppConstants.statusDegraded,
      location:      'Data Centre',
      description:   'Optical Line Terminal — fibre customers',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      _ago(minutes: 10),
      createdAt:     _ago(days: 300),
    ),
    DeviceModel(
      id:            4,
      name:          'AP — Rooftop',
      ipAddress:     '192.168.1.30',
      macAddress:    'AA:BB:CC:DD:EE:04',
      deviceType:    AppConstants.deviceAccessPoint,
      status:        AppConstants.statusOffline,
      location:      'Rooftop Tower',
      description:   'Wireless AP covering surrounding estates',
      snmpEnabled:   false,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      _ago(hours: 1, minutes: 25),
      createdAt:     _ago(days: 270),
    ),
    DeviceModel(
      id:            5,
      name:          'Backup Router',
      ipAddress:     '192.168.1.5',
      macAddress:    'AA:BB:CC:DD:EE:05',
      deviceType:    AppConstants.deviceRouter,
      status:        AppConstants.statusOnline,
      location:      'Server Room',
      description:   'Failover router — active when core router is down',
      snmpEnabled:   true,
      snmpCommunity: 'private',
      isActive:      true,
      lastSeen:      _ago(minutes: 5),
      createdAt:     _ago(days: 250),
    ),
    DeviceModel(
      id:            6,
      name:          'Access Switch B',
      ipAddress:     '192.168.1.11',
      macAddress:    'AA:BB:CC:DD:EE:06',
      deviceType:    AppConstants.deviceSwitch,
      status:        AppConstants.statusOnline,
      location:      'Distribution Cabinet — Block B',
      description:   '24-port managed switch serving Block B customers',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      _ago(minutes: 7),
      createdAt:     _ago(days: 200),
    ),
    DeviceModel(
      id:            7,
      name:          'OLT-02',
      ipAddress:     '192.168.1.21',
      macAddress:    'AA:BB:CC:DD:EE:07',
      deviceType:    AppConstants.deviceOlt,
      status:        AppConstants.statusOnline,
      location:      'Data Centre',
      description:   'Secondary OLT — residential fibre zone 2',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      _ago(minutes: 5),
      createdAt:     _ago(days: 180),
    ),
    DeviceModel(
      id:            8,
      name:          'AP — Block C',
      ipAddress:     '192.168.1.31',
      macAddress:    'AA:BB:CC:DD:EE:08',
      deviceType:    AppConstants.deviceAccessPoint,
      status:        AppConstants.statusDegraded,
      location:      'Block C Corridor',
      description:   'Indoor AP with elevated error rate',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      _ago(minutes: 15),
      createdAt:     _ago(days: 90),
    ),
  ];

  // ── Latest metrics (one per device) ──────────────────────────────────────

  static final List<MetricModel> latestMetrics = [
    MetricModel(
      id: 1, deviceId: 1,
      latencyMs: 12.4, packetLossPct: 0.0,
      bandwidthInBps: 45000000, bandwidthOutBps: 38000000,
      cpuUsagePct: 34.0, memoryUsagePct: 52.0,
      interfaceErrors: 0, uptimeSeconds: 864000,
      macTableEntries: 4200, powerLoadPct: 48.0,
      pollMethod: 'snmp', recordedAt: _ago(minutes: 5),
    ),
    MetricModel(
      id: 2, deviceId: 2,
      latencyMs: 8.1, packetLossPct: 0.0,
      bandwidthInBps: 12000000, bandwidthOutBps: 9500000,
      cpuUsagePct: 18.0, memoryUsagePct: 31.0,
      interfaceErrors: 2, uptimeSeconds: 432000,
      macTableEntries: 2100, powerLoadPct: 34.0,
      pollMethod: 'snmp', recordedAt: _ago(minutes: 5),
    ),
    MetricModel(
      id: 3, deviceId: 3,
      latencyMs: 245.0, packetLossPct: 8.5,
      bandwidthInBps: 5000000, bandwidthOutBps: 4200000,
      cpuUsagePct: 78.0, memoryUsagePct: 85.0,
      interfaceErrors: 24, uptimeSeconds: 259200,
      macTableEntries: 11800, powerLoadPct: 86.0,
      pollMethod: 'snmp', recordedAt: _ago(minutes: 10),
    ),
    MetricModel(
      id: 4, deviceId: 4,
      latencyMs: null, packetLossPct: 100.0,
      bandwidthInBps: null, bandwidthOutBps: null,
      cpuUsagePct: null, memoryUsagePct: null,
      interfaceErrors: null, uptimeSeconds: null,
      macTableEntries: null, powerLoadPct: null,
      pollMethod: 'icmp', recordedAt: _ago(hours: 1, minutes: 25),
    ),
    MetricModel(
      id: 5, deviceId: 5,
      latencyMs: 15.2, packetLossPct: 0.0,
      bandwidthInBps: 8000000, bandwidthOutBps: 6500000,
      cpuUsagePct: 22.0, memoryUsagePct: 44.0,
      interfaceErrors: 0, uptimeSeconds: 600000,
      macTableEntries: 3900, powerLoadPct: 40.0,
      pollMethod: 'snmp', recordedAt: _ago(minutes: 5),
    ),
    MetricModel(
      id: 6, deviceId: 6,
      latencyMs: 9.8, packetLossPct: 0.0,
      bandwidthInBps: 14000000, bandwidthOutBps: 11000000,
      cpuUsagePct: 21.0, memoryUsagePct: 28.0,
      interfaceErrors: 0, uptimeSeconds: 518400,
      macTableEntries: 3000, powerLoadPct: 36.0,
      pollMethod: 'snmp', recordedAt: _ago(minutes: 7),
    ),
    MetricModel(
      id: 7, deviceId: 7,
      latencyMs: 11.0, packetLossPct: 0.1,
      bandwidthInBps: 22000000, bandwidthOutBps: 19000000,
      cpuUsagePct: 41.0, memoryUsagePct: 60.0,
      interfaceErrors: 1, uptimeSeconds: 720000,
      macTableEntries: 5200, powerLoadPct: 55.0,
      pollMethod: 'snmp', recordedAt: _ago(minutes: 5),
    ),
    MetricModel(
      id: 8, deviceId: 8,
      latencyMs: 188.0, packetLossPct: 3.2,
      bandwidthInBps: 3000000, bandwidthOutBps: 2400000,
      cpuUsagePct: 67.0, memoryUsagePct: 72.0,
      interfaceErrors: 9, uptimeSeconds: 172800,
      macTableEntries: 9100, powerLoadPct: 79.0,
      pollMethod: 'snmp', recordedAt: _ago(minutes: 15),
    ),
  ];

  // ── Metric predictions (short-horizon risk) ─────────────────────────────

  static final List<MetricPredictionModel> metricPredictions = [
    MetricPredictionModel(
      id: 1,
      deviceId: 3,
      deviceName: 'OLT-01',
      metricId: 1,
      metricName: 'latency_ms',
      metricUnit: 'ms',
      predictedValue: 320.0,
      slopePerMin: 1.8,
      riskLevel: 'critical',
      horizonMinutes: 60,
      generatedAt: _ago(minutes: 5),
    ),
    MetricPredictionModel(
      id: 2,
      deviceId: 3,
      deviceName: 'OLT-01',
      metricId: 2,
      metricName: 'memory_usage_pct',
      metricUnit: '%',
      predictedValue: 92.0,
      slopePerMin: 0.4,
      riskLevel: 'high',
      horizonMinutes: 60,
      generatedAt: _ago(minutes: 5),
    ),
    MetricPredictionModel(
      id: 3,
      deviceId: 8,
      deviceName: 'AP-Block C',
      metricId: 3,
      metricName: 'mac_table_entries',
      metricUnit: 'count',
      predictedValue: 9800.0,
      slopePerMin: 2.1,
      riskLevel: 'high',
      horizonMinutes: 60,
      generatedAt: _ago(minutes: 8),
    ),
  ];

  // ── Metric history (7-day time series per device) ─────────────────────────
  // Used by reports screen charts and device detail latency graphs.
  // Each entry is one hourly poll snapshot.

  static final Map<int, List<MetricModel>> metricHistory = {
    // Core Router — stable, low latency
    1: List.generate(7, (day) => MetricModel(
      id:          100 + day,
      deviceId:    1,
      latencyMs:   10.0 + (day % 3) * 2.5,
      packetLossPct: 0.0,
      cpuUsagePct:   30.0 + (day % 4) * 3,
      memoryUsagePct: 50.0 + (day % 3) * 2,
      bandwidthInBps:  40000000,
      bandwidthOutBps: 35000000,
      interfaceErrors: 0,
      uptimeSeconds:   864000 - (day * 86400),
      pollMethod: 'snmp',
      recordedAt: _ago(days: 6 - day),
    )),

    // OLT-01 — degraded, high latency trending up
    3: List.generate(7, (day) => MetricModel(
      id:          200 + day,
      deviceId:    3,
      latencyMs:   80.0 + (day * 25.0),
      packetLossPct: day < 4 ? 0.5 : 4.0 + (day - 4) * 2.0,
      cpuUsagePct:    40.0 + (day * 6.0),
      memoryUsagePct: 55.0 + (day * 4.5),
      bandwidthInBps:  8000000 - (day * 500000),
      bandwidthOutBps: 6000000 - (day * 400000),
      interfaceErrors: day * 4,
      uptimeSeconds:   259200,
      pollMethod: 'snmp',
      recordedAt: _ago(days: 6 - day),
    )),
  };

  // ── Alerts ────────────────────────────────────────────────────────────────

  static final List<AlertModel> alerts = [
    AlertModel(
      id: 1, deviceId: 4, deviceName: 'AP — Rooftop',
      alertType: 'device_offline', severity: AppConstants.severityCritical,
      message:   'AP — Rooftop (192.168.1.30) is unreachable.',
      isResolved: false, isAcknowledged: false,
      triggeredAt: _ago(hours: 1, minutes: 25),
    ),
    AlertModel(
      id: 2, deviceId: 3, deviceName: 'OLT-01',
      alertType: 'high_latency', severity: AppConstants.severityHigh,
      message: 'High latency on OLT-01: 245 ms (threshold: 200 ms)',
      details: {'latency_ms': 245.0, 'threshold': 200},
      isResolved: false, isAcknowledged: true,
      triggeredAt: _ago(minutes: 40),
    ),
    AlertModel(
      id: 3, deviceId: 3, deviceName: 'OLT-01',
      alertType: 'packet_loss', severity: AppConstants.severityHigh,
      message: 'Packet loss on OLT-01: 8.5% (threshold: 5%)',
      details: {'packet_loss_pct': 8.5, 'threshold': 5},
      isResolved: false, isAcknowledged: false,
      triggeredAt: _ago(minutes: 38),
    ),
    AlertModel(
      id: 4, deviceId: 3, deviceName: 'OLT-01',
      alertType: 'high_memory', severity: AppConstants.severityHigh,
      message: 'High memory usage on OLT-01: 85% (threshold: 80%)',
      details: {'memory_usage_pct': 85.0, 'threshold': 80},
      isResolved: false, isAcknowledged: false,
      triggeredAt: _ago(minutes: 35),
    ),
    AlertModel(
      id: 5, deviceId: 8, deviceName: 'AP — Block C',
      alertType: 'high_latency', severity: AppConstants.severityMedium,
      message: 'Elevated latency on AP — Block C: 188 ms',
      details: {'latency_ms': 188.0, 'threshold': 150},
      isResolved: false, isAcknowledged: false,
      triggeredAt: _ago(minutes: 20),
    ),
    AlertModel(
      id: 6, deviceId: 8, deviceName: 'AP — Block C',
      alertType: 'interface_error', severity: AppConstants.severityMedium,
      message: 'Interface errors on AP — Block C: 9 errors/min',
      details: {'interface_errors': 9},
      isResolved: false, isAcknowledged: false,
      triggeredAt: _ago(minutes: 18),
    ),
    AlertModel(
      id: 7, deviceId: 1, deviceName: 'Core Router',
      alertType: 'interface_error', severity: AppConstants.severityLow,
      message: 'Minor interface errors on Core Router: 2 errors',
      details: {'interface_errors': 2},
      isResolved: true, isAcknowledged: true,
      triggeredAt: _ago(hours: 8),
      resolvedAt:  _ago(hours: 7, minutes: 15),
    ),
    AlertModel(
      id: 8, deviceId: 2, deviceName: 'Access Switch A',
      alertType: 'high_cpu', severity: AppConstants.severityLow,
      message: 'Briefly high CPU on Access Switch A: 91% (now resolved)',
      details: {'cpu_usage_pct': 91.0},
      isResolved: true, isAcknowledged: true,
      triggeredAt: _ago(days: 1),
      resolvedAt:  _ago(hours: 23),
    ),
  ];

  // ── Notifications ─────────────────────────────────────────────────────────
  // Separate from alerts — notifications are the in-app inbox items.

  static final List<Map<String, dynamic>> notifications = [
    {
      'id':        1,
      'title':     'Device Offline',
      'body':      'AP — Rooftop has been unreachable for 85 minutes.',
      'type':      'alert',
      'severity':  AppConstants.severityCritical,
      'read':      false,
      'createdAt': _ago(hours: 1, minutes: 25),
    },
    {
      'id':        2,
      'title':     'High Latency Detected',
      'body':      'OLT-01 latency has risen to 245 ms. Threshold: 200 ms.',
      'type':      'alert',
      'severity':  AppConstants.severityHigh,
      'read':      false,
      'createdAt': _ago(minutes: 40),
    },
    {
      'id':        3,
      'title':     'Alert Resolved',
      'body':      'Interface errors on Core Router have cleared.',
      'type':      'resolved',
      'severity':  AppConstants.severityLow,
      'read':      true,
      'createdAt': _ago(hours: 7, minutes: 15),
    },
    {
      'id':        4,
      'title':     'Scheduled Maintenance',
      'body':      'OLT-01 maintenance window starts tomorrow at 02:00.',
      'type':      'info',
      'severity':  'info',
      'read':      true,
      'createdAt': _ago(hours: 12),
    },
    {
      'id':        5,
      'title':     'New Device Added',
      'body':      'AP — Block C was added to the monitoring system.',
      'type':      'info',
      'severity':  'info',
      'read':      true,
      'createdAt': _ago(days: 2),
    },
  ];

  // ── Weekly fault counts (for dashboard bar chart) ─────────────────────────
  // 7 entries, one per day, index 0 = 6 days ago, index 6 = today.

  static final List<Map<String, dynamic>> weeklyFaults = List.generate(7, (i) {
    final counts = [3, 5, 2, 7, 4, 6, 4]; // Sun → today
    return {
      'date':   _ago(days: 6 - i),
      'faults': counts[i],
      'isToday': i == 6,
    };
  });

  // ── Dashboard Summary ─────────────────────────────────────────────────────
  // Derived from actual device/alert counts above for consistency.

  static final Map<String, dynamic> dashboardSummary = {
    'total_devices':      devices.length,                                    // 8
    'online_devices':     devices.where((d) => d.status == AppConstants.statusOnline).length,    // 5
    'offline_devices':    devices.where((d) => d.status == AppConstants.statusOffline).length,   // 1
    'degraded_devices':   devices.where((d) => d.status == AppConstants.statusDegraded).length,  // 2
    'active_alerts':      alerts.where((a) => !a.isResolved).length,         // 6
    'critical_alerts':    alerts.where((a) =>
        !a.isResolved && a.severity == AppConstants.severityCritical).length, // 1
    'network_uptime_pct': 96.8,   // weighted — degraded devices penalise this
    'avg_latency_ms':     64.3,   // average of all online device latencies
    'faults_this_week':   weeklyFaults.fold(0, (sum, d) => sum + (d['faults'] as int)),
    'avg_mttr_minutes':   23,
  };

  // ── Monitoring Tasks ──────────────────────────────────────────────────────
  // Scheduled monitoring tasks matching the Django MonitoringTask model.

  static final List<TaskModel> tasks = [
    TaskModel(
      id: 1, name: 'Install 3 clients',
      description: 'Install CPE, align antenna, configure router, verify throughput, photos + client sign-off.',
      deviceId: null, deviceName: null,
      taskType: 'install', intervalSecs: 86400, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(hours: 6), lastStatus: 'partial',
      createdAt: _ago(days: 14),
    ),
    TaskModel(
      id: 2, name: 'CO site survey',
      description: 'LOS check, signal strength, obstruction notes, photos, GPS pin.',
      deviceId: null, deviceName: null,
      taskType: 'survey', intervalSecs: 86400, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(days: 1), lastStatus: 'completed',
      createdAt: _ago(days: 20),
    ),
    TaskModel(
      id: 3, name: 'Fault resolution visit',
      description: 'Replace CPE if needed, re-terminate fiber, change power supply, port swap, verify.',
      deviceId: null, deviceName: null,
      taskType: 'fault', intervalSecs: 43200, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(hours: 3), lastStatus: 'not_done',
      createdAt: _ago(days: 7),
    ),
    TaskModel(
      id: 4, name: 'Preventive maintenance',
      description: 'Clean/inspect tower, tighten brackets, label cables, photo evidence.',
      deviceId: null, deviceName: null,
      taskType: 'maintenance', intervalSecs: 604800, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(days: 3), lastStatus: 'completed',
      createdAt: _ago(days: 30),
    ),
    TaskModel(
      id: 5, name: 'Network change',
      description: 'VLAN setup, IP changes, firmware upgrade, config backup/restore.',
      deviceId: null, deviceName: null,
      taskType: 'change', intervalSecs: 86400, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(days: 2), lastStatus: 'partial',
      createdAt: _ago(days: 18),
    ),
    TaskModel(
      id: 6, name: 'Field audit',
      description: 'Inventory check, serial/MAC verification, cable trace, photos.',
      deviceId: null, deviceName: null,
      taskType: 'audit', intervalSecs: 604800, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(days: 5), lastStatus: 'completed',
      createdAt: _ago(days: 40),
    ),
    TaskModel(
      id: 7, name: 'Network expansion',
      description: 'Pole install, new AP mounting, sector alignment, verification.',
      deviceId: null, deviceName: null,
      taskType: 'expansion', intervalSecs: 86400, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(days: 4), lastStatus: 'partial',
      createdAt: _ago(days: 22),
    ),
    TaskModel(
      id: 8, name: 'Customer support visit',
      description: 'Wi-Fi optimization, coverage tuning, speed validation, client sign-off.',
      deviceId: null, deviceName: null,
      taskType: 'support', intervalSecs: 43200, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(hours: 8), lastStatus: 'completed',
      createdAt: _ago(days: 12),
    ),
    TaskModel(
      id: 9, name: 'Run ads at Kathembony',
      description: 'Place ads at agreed spots, photos, brief report.',
      deviceId: null, deviceName: null,
      taskType: 'marketing', intervalSecs: 86400, timeoutSecs: 30,
      enabled: true,
      lastRun: _ago(days: 1), lastStatus: 'not_done',
      createdAt: _ago(days: 9),
    ),
  ];

  // ── Reports ───────────────────────────────────────────────────────────────
  // Pre-generated periodic performance reports.

  static final List<ReportModel> reports = [
    ReportModel(
      id: 1,
      title: 'Daily Network Report',
      type: 'daily',
      status: 'completed',
      periodStart: _ago(days: 1),
      periodEnd: _ago(minutes: 1),
      generatedAt: _ago(minutes: 5),
      uptimePct: 96.8,
      avgLatencyMs: 64.3,
      totalAlerts: 8,
      resolvedAlerts: 2,
      totalDevices: 8,
      onlineDevices: 5,
      offlineDevices: 1,
      degradedDevices: 2,
      avgMttrMinutes: 23,
      totalFaults: 4,
      dailyLatency: List.generate(24, (h) => {
        'hour': '${h.toString().padLeft(2, '0')}:00',
        'value': 30.0 + (h % 6) * 12.0 + (h > 18 ? 40.0 : 0.0),
      }),
      alertsBySeverity: [
        {'severity': 'critical', 'count': 1},
        {'severity': 'high', 'count': 3},
        {'severity': 'medium', 'count': 2},
        {'severity': 'low', 'count': 2},
      ],
    ),
    ReportModel(
      id: 2,
      title: 'Weekly Network Report',
      type: 'weekly',
      status: 'completed',
      periodStart: _ago(days: 7),
      periodEnd: _ago(minutes: 1),
      generatedAt: _ago(hours: 1),
      uptimePct: 95.4,
      avgLatencyMs: 72.1,
      totalAlerts: 31,
      resolvedAlerts: 22,
      totalDevices: 8,
      onlineDevices: 5,
      offlineDevices: 1,
      degradedDevices: 2,
      avgMttrMinutes: 28,
      totalFaults: 31,
      dailyLatency: List.generate(7, (d) => {
        'day': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d],
        'value': 40.0 + (d % 3) * 20.0 + (d == 4 ? 55.0 : 0.0),
      }),
      alertsBySeverity: [
        {'severity': 'critical', 'count': 3},
        {'severity': 'high', 'count': 10},
        {'severity': 'medium', 'count': 9},
        {'severity': 'low', 'count': 9},
      ],
    ),
    ReportModel(
      id: 3,
      title: 'Monthly Network Report',
      type: 'monthly',
      status: 'completed',
      periodStart: _ago(days: 30),
      periodEnd: _ago(minutes: 1),
      generatedAt: _ago(hours: 6),
      uptimePct: 97.2,
      avgLatencyMs: 58.7,
      totalAlerts: 124,
      resolvedAlerts: 108,
      totalDevices: 8,
      onlineDevices: 5,
      offlineDevices: 1,
      degradedDevices: 2,
      avgMttrMinutes: 19,
      totalFaults: 89,
      dailyLatency: List.generate(30, (d) => {
        'day': 'Day ${d + 1}',
        'value': 35.0 + (d % 5) * 10.0 + (d == 14 ? 80.0 : 0.0),
      }),
      alertsBySeverity: [
        {'severity': 'critical', 'count': 8},
        {'severity': 'high', 'count': 35},
        {'severity': 'medium', 'count': 42},
        {'severity': 'low', 'count': 39},
      ],
    ),
    ReportModel(
      id: 4,
      title: 'Previous Week Report',
      type: 'weekly',
      status: 'completed',
      periodStart: _ago(days: 14),
      periodEnd: _ago(days: 7),
      generatedAt: _ago(days: 7),
      uptimePct: 98.1,
      avgLatencyMs: 45.2,
      totalAlerts: 18,
      resolvedAlerts: 17,
      totalDevices: 8,
      onlineDevices: 6,
      offlineDevices: 0,
      degradedDevices: 2,
      avgMttrMinutes: 15,
      totalFaults: 18,
      dailyLatency: List.generate(7, (d) => {
        'day': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d],
        'value': 30.0 + (d % 4) * 8.0,
      }),
      alertsBySeverity: [
        {'severity': 'critical', 'count': 1},
        {'severity': 'high', 'count': 5},
        {'severity': 'medium', 'count': 6},
        {'severity': 'low', 'count': 6},
      ],
    ),
    ReportModel(
      id: 5,
      title: 'Yesterday\'s Report',
      type: 'daily',
      status: 'completed',
      periodStart: _ago(days: 2),
      periodEnd: _ago(days: 1),
      generatedAt: _ago(days: 1),
      uptimePct: 99.1,
      avgLatencyMs: 38.4,
      totalAlerts: 5,
      resolvedAlerts: 5,
      totalDevices: 8,
      onlineDevices: 7,
      offlineDevices: 0,
      degradedDevices: 1,
      avgMttrMinutes: 12,
      totalFaults: 3,
      dailyLatency: List.generate(24, (h) => {
        'hour': '${h.toString().padLeft(2, '0')}:00',
        'value': 25.0 + (h % 4) * 6.0,
      }),
      alertsBySeverity: [
        {'severity': 'critical', 'count': 0},
        {'severity': 'high', 'count': 1},
        {'severity': 'medium', 'count': 2},
        {'severity': 'low', 'count': 2},
      ],
    ),
    ReportModel(
      id: 6,
      title: 'Generating Report…',
      type: 'daily',
      status: 'generating',
      periodStart: _ago(hours: 12),
      periodEnd: _ago(minutes: 0),
      generatedAt: _ago(minutes: 0),
      uptimePct: 0,
      avgLatencyMs: 0,
      totalAlerts: 0,
      resolvedAlerts: 0,
      totalDevices: 0,
      onlineDevices: 0,
      offlineDevices: 0,
      degradedDevices: 0,
      avgMttrMinutes: 0,
      totalFaults: 0,
    ),
  ];
}