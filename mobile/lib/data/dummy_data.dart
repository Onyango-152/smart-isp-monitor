import 'models/device_model.dart';
import 'models/metric_model.dart';
import 'models/alert_model.dart';
import 'models/user_model.dart';

/// DummyData provides realistic hardcoded data for every screen.
/// When we integrate the backend on integration day, each screen's
/// provider will swap these static lists for real API calls.
/// The data shapes exactly match what the Django API will return.
class DummyData {
  DummyData._();

  // ── Users ─────────────────────────────────────────────────────────────
  static const UserModel technicianUser = UserModel(
    id:         1,
    email:      'technician@isp.co.ke',
    username:   'technician',
    role:       'technician',
    isActive:   true,
    dateJoined: '2024-01-15T08:00:00Z',
    lastLogin:  '2025-03-02T07:30:00Z',
  );

  static const UserModel managerUser = UserModel(
    id:         2,
    email:      'manager@isp.co.ke',
    username:   'manager',
    role:       'manager',
    isActive:   true,
    dateJoined: '2024-01-10T08:00:00Z',
    lastLogin:  '2025-03-02T07:00:00Z',
  );

  static const UserModel customerUser = UserModel(
    id:         3,
    email:      'customer@isp.co.ke',
    username:   'customer',
    role:       'customer',
    isActive:   true,
    dateJoined: '2024-06-01T08:00:00Z',
    lastLogin:  '2025-03-01T18:00:00Z',
  );

  // ── Devices ───────────────────────────────────────────────────────────
  static final List<DeviceModel> devices = [
    const DeviceModel(
      id:            1,
      name:          'Core Router',
      ipAddress:     '192.168.1.1',
      macAddress:    'AA:BB:CC:DD:EE:01',
      deviceType:    'router',
      status:        'online',
      location:      'Server Room',
      description:   'Main core router connecting upstream ISP link',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      '2025-03-02T07:55:00Z',
      createdAt:     '2024-01-15T08:00:00Z',
    ),
    const DeviceModel(
      id:            2,
      name:          'Access Switch A',
      ipAddress:     '192.168.1.10',
      macAddress:    'AA:BB:CC:DD:EE:02',
      deviceType:    'switch',
      status:        'online',
      location:      'Distribution Cabinet - Block A',
      description:   '24-port managed switch serving Block A customers',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      '2025-03-02T07:55:00Z',
      createdAt:     '2024-01-15T08:00:00Z',
    ),
    const DeviceModel(
      id:            3,
      name:          'OLT-01',
      ipAddress:     '192.168.1.20',
      macAddress:    'AA:BB:CC:DD:EE:03',
      deviceType:    'olt',
      status:        'degraded',
      location:      'Data Centre',
      description:   'Optical Line Terminal serving fibre customers',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      '2025-03-02T07:50:00Z',
      createdAt:     '2024-02-01T08:00:00Z',
    ),
    const DeviceModel(
      id:            4,
      name:          'Access Point - Roof',
      ipAddress:     '192.168.1.30',
      macAddress:    'AA:BB:CC:DD:EE:04',
      deviceType:    'access_point',
      status:        'offline',
      location:      'Rooftop Tower',
      description:   'Wireless access point covering surrounding estates',
      snmpEnabled:   false,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      '2025-03-02T06:30:00Z',
      createdAt:     '2024-03-01T08:00:00Z',
    ),
    const DeviceModel(
      id:            5,
      name:          'Backup Router',
      ipAddress:     '192.168.1.5',
      macAddress:    'AA:BB:CC:DD:EE:05',
      deviceType:    'router',
      status:        'online',
      location:      'Server Room',
      description:   'Failover router — active when core router is down',
      snmpEnabled:   true,
      snmpCommunity: 'public',
      isActive:      true,
      lastSeen:      '2025-03-02T07:55:00Z',
      createdAt:     '2024-03-15T08:00:00Z',
    ),
  ];

  // ── Metrics (latest snapshot per device) ──────────────────────────────
  static final List<MetricModel> latestMetrics = [
    const MetricModel(
      id: 1, deviceId: 1,
      latencyMs: 12.4, packetLossPct: 0.0,
      bandwidthInBps: 45000000, bandwidthOutBps: 38000000,
      cpuUsagePct: 34.0, memoryUsagePct: 52.0,
      interfaceErrors: 0, uptimeSeconds: 864000,
      pollMethod: 'snmp', recordedAt: '2025-03-02T07:55:00Z',
    ),
    const MetricModel(
      id: 2, deviceId: 2,
      latencyMs: 8.1, packetLossPct: 0.0,
      bandwidthInBps: 12000000, bandwidthOutBps: 9500000,
      cpuUsagePct: 18.0, memoryUsagePct: 31.0,
      interfaceErrors: 2, uptimeSeconds: 432000,
      pollMethod: 'snmp', recordedAt: '2025-03-02T07:55:00Z',
    ),
    const MetricModel(
      id: 3, deviceId: 3,
      latencyMs: 245.0, packetLossPct: 8.5,
      bandwidthInBps: 5000000, bandwidthOutBps: 4200000,
      cpuUsagePct: 78.0, memoryUsagePct: 85.0,
      interfaceErrors: 24, uptimeSeconds: 259200,
      pollMethod: 'snmp', recordedAt: '2025-03-02T07:50:00Z',
    ),
    const MetricModel(
      id: 4, deviceId: 4,
      latencyMs: null, packetLossPct: 100.0,
      bandwidthInBps: null, bandwidthOutBps: null,
      cpuUsagePct: null, memoryUsagePct: null,
      interfaceErrors: null, uptimeSeconds: null,
      pollMethod: 'icmp', recordedAt: '2025-03-02T06:30:00Z',
    ),
  ];

  // ── Alerts ────────────────────────────────────────────────────────────
  static final List<AlertModel> alerts = [
    const AlertModel(
      id: 1, deviceId: 4, deviceName: 'Access Point - Roof',
      alertType: 'device_offline', severity: 'critical',
      message: 'Device Access Point - Roof (192.168.1.30) is unreachable.',
      isResolved: false, isAcknowledged: false,
      triggeredAt: '2025-03-02T06:31:00Z',
    ),
    const AlertModel(
      id: 2, deviceId: 3, deviceName: 'OLT-01',
      alertType: 'high_latency', severity: 'high',
      message: 'High latency on OLT-01: 245ms (threshold: 200ms)',
      details: {'latency_ms': 245.0, 'threshold': 200},
      isResolved: false, isAcknowledged: true,
      triggeredAt: '2025-03-02T07:20:00Z',
    ),
    const AlertModel(
      id: 3, deviceId: 3, deviceName: 'OLT-01',
      alertType: 'packet_loss', severity: 'high',
      message: 'Packet loss on OLT-01: 8.5% (threshold: 5%)',
      details: {'packet_loss_pct': 8.5, 'threshold': 5},
      isResolved: false, isAcknowledged: false,
      triggeredAt: '2025-03-02T07:22:00Z',
    ),
    const AlertModel(
      id: 4, deviceId: 3, deviceName: 'OLT-01',
      alertType: 'high_cpu', severity: 'high',
      message: 'High CPU usage on OLT-01: 78% (threshold: 80%)',
      details: {'cpu_usage_pct': 78.0},
      isResolved: false, isAcknowledged: false,
      triggeredAt: '2025-03-02T07:25:00Z',
    ),
    const AlertModel(
      id: 5, deviceId: 1, deviceName: 'Core Router',
      alertType: 'interface_error', severity: 'low',
      message: 'Interface errors detected on Core Router: 12 errors',
      details: {'interface_errors': 12},
      isResolved: true, isAcknowledged: true,
      triggeredAt: '2025-03-01T14:00:00Z',
      resolvedAt:  '2025-03-01T14:45:00Z',
    ),
  ];

  // ── Dashboard Summary ─────────────────────────────────────────────────
  static final Map<String, dynamic> dashboardSummary = {
    'total_devices':        5,
    'online_devices':       3,
    'offline_devices':      1,
    'degraded_devices':     1,
    'active_alerts':        4,
    'critical_alerts':      1,
    'network_uptime_pct':   94.5,
    'avg_latency_ms':       88.6,
    'faults_this_week':     7,
    'avg_mttr_minutes':     23,
  };
}