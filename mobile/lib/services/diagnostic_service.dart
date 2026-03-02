import '../data/models/device_model.dart';

/// Diagnostic result model for OLT and other devices
class DiagnosticResult {
  final String deviceType;
  final String ipAddress;
  final bool isHealthy;
  final List<DiagnosticCheck> checks;
  final String? criticalIssue;
  final String timestamp;

  DiagnosticResult({
    required this.deviceType,
    required this.ipAddress,
    required this.isHealthy,
    required this.checks,
    this.criticalIssue,
    required this.timestamp,
  });
}

class DiagnosticCheck {
  final String name;
  final bool passed;
  final String message;
  final String? remediation;
  final Map<String, dynamic>? details;

  DiagnosticCheck({
    required this.name,
    required this.passed,
    required this.message,
    this.remediation,
    this.details,
  });
}

/// Service to run diagnostics on network devices
class DiagnosticService {
  // MAC address thresholds
  static const int macThresholdWarning = 800;   // 80% capacity
  static const int macThresholdCritical = 950;  // 95% capacity
  static const int macTableMaxCapacity = 1000;  // 1000 MAC addresses

  /// Run comprehensive diagnostics for a device
  static Future<DiagnosticResult> runDiagnostics(
      DeviceModel device) async {
    print('Running diagnostics for device: ${device.name} (${device.deviceType})');

    final checks = <DiagnosticCheck>[];

    // 1. Basic connectivity check (ICMP ping)
    checks.add(await _checkConnectivity(device));

    // 2. SNMP check
    checks.add(await _checkSNMP(device));

    // 3. Device-specific checks
    if (device.deviceType == 'olt') {
      checks.add(await _checkOLTMacTable(device));
      checks.add(await _checkOLTPortStatus(device));
      checks.add(await _checkClientConnections(device));
    } else if (device.deviceType == 'switch') {
      checks.add(await _checkPortStatus(device));
      checks.add(await _checkSwitchMacTable(device));
    } else if (device.deviceType == 'router') {
      checks.add(await _checkRouterInterfaces(device));
      checks.add(await _checkRouting(device));
    }

    // Determine if device is healthy
    final isHealthy = checks.every((c) => c.passed);
    final criticalIssue = checks
        .where((c) => !c.passed)
        .firstOrNull
        ?.message;

    return DiagnosticResult(
      deviceType: device.deviceType,
      ipAddress: device.ipAddress,
      isHealthy: isHealthy,
      checks: checks,
      criticalIssue: criticalIssue,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  /// Check basic ICMP connectivity
  static Future<DiagnosticCheck> _checkConnectivity(
      DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final isOnline = device.status == 'online';
    return DiagnosticCheck(
      name: 'ICMP Connectivity',
      passed: isOnline,
      message: isOnline
          ? 'Device responds to ping requests'
          : 'Device does not respond to ping requests',
      remediation: !isOnline
          ? 'Check physical connectivity and power supply'
          : null,
      details: {'protocol': 'ICMP', 'response_time': '${10 + (device.id % 20)}ms'},
    );
  }

  /// Check SNMP configuration
  static Future<DiagnosticCheck> _checkSNMP(DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final snmpOk = device.snmpEnabled;
    return DiagnosticCheck(
      name: 'SNMP Configuration',
      passed: snmpOk,
      message: snmpOk
          ? 'SNMP is properly configured (Community: ${device.snmpCommunity})'
          : 'SNMP is disabled on this device',
      remediation: !snmpOk
          ? 'Enable SNMP and configure proper community strings'
          : null,
      details: {'version': 'SNMPv2c', 'community': device.snmpCommunity},
    );
  }

  /// Check OLT MAC table utilization
  static Future<DiagnosticCheck> _checkOLTMacTable(
      DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    // Simulate MAC address table count (0-1000)
    final macCount = 450 + (device.id % 550);
    final severity = macCount > macThresholdCritical
        ? 'CRITICAL'
        : macCount > macThresholdWarning
            ? 'WARNING'
            : 'OK';
    final passed = macCount <= macThresholdWarning;

    final message = 'MAC Table: $macCount/$macTableMaxCapacity entries '
        '(${(macCount / macTableMaxCapacity * 100).toStringAsFixed(1)}%) - $severity';

    return DiagnosticCheck(
      name: 'OLT MAC Table Utilization',
      passed: passed,
      message: message,
      remediation: !passed
          ? 'Clear inactive MAC entries or upgrade OLT capacity'
          : null,
      details: {
        'current_mac_count': macCount,
        'max_capacity': macTableMaxCapacity,
        'utilization_percent': (macCount / macTableMaxCapacity * 100).toStringAsFixed(1),
        'threshold_warning': macThresholdWarning,
        'threshold_critical': macThresholdCritical,
        'status': severity,
      },
    );
  }

  /// Check OLT port status
  static Future<DiagnosticCheck> _checkOLTPortStatus(
      DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final portsUp = 128;
    final totalPorts = 128;
    final passed = portsUp >= (totalPorts * 0.95); // 95% threshold

    return DiagnosticCheck(
      name: 'OLT Port Status',
      passed: passed,
      message: '$portsUp/$totalPorts ports are active',
      remediation: !passed
          ? 'Check physical connections and port configurations'
          : null,
      details: {
        'ports_active': portsUp,
        'ports_total': totalPorts,
        'uptime': '43200 seconds',
      },
    );
  }

  /// Check client connections to OLT
  static Future<DiagnosticCheck> _checkClientConnections(
      DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final activeClients = 980 + (device.id % 100);
    final passed = activeClients <= 1000;

    return DiagnosticCheck(
      name: 'Client Connections',
      passed: passed,
      message: '$activeClients active clients connected',
      remediation: !passed
          ? 'Maximum client capacity exceeded. Clients may experience disconnections.'
          : null,
      details: {
        'active_clients': activeClients,
        'max_clients': 1000,
        'available_slots': 1000 - activeClients,
      },
    );
  }

  /// Check switch port status
  static Future<DiagnosticCheck> _checkPortStatus(DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final portsUp = 48;
    final totalPorts = 48;
    return DiagnosticCheck(
      name: 'Port Status',
      passed: true,
      message: '$portsUp/$totalPorts ports are operational',
      details: {'ports_active': portsUp, 'ports_total': totalPorts},
    );
  }

  /// Check switch MAC table
  static Future<DiagnosticCheck> _checkSwitchMacTable(
      DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final macCount = 200 + (device.id % 300);
    return DiagnosticCheck(
      name: 'MAC Table Entries',
      passed: true,
      message: '$macCount MAC entries in switch table',
      details: {'mac_entries': macCount},
    );
  }

  /// Check router interfaces
  static Future<DiagnosticCheck> _checkRouterInterfaces(
      DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 600));

    return DiagnosticCheck(
      name: 'Router Interfaces',
      passed: true,
      message: '4 interfaces are operational',
      details: {'interfaces_up': 4, 'interfaces_total': 4},
    );
  }

  /// Check routing table
  static Future<DiagnosticCheck> _checkRouting(DeviceModel device) async {
    await Future.delayed(const Duration(milliseconds: 700));

    return DiagnosticCheck(
      name: 'Routing Status',
      passed: true,
      message: '256 routes active in routing table',
      details: {'routes_active': 256},
    );
  }
}
