import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';

/// DiagnosticResult holds the outcome of a single diagnostic check.
class DiagnosticResult {
  final String     checkName;
  final bool       passed;
  final String     finding;     // what was found
  final String     alertType;   // what alert type this maps to for troubleshooting
  final double?    value;       // the measured value
  final double?    threshold;   // the threshold it was compared against

  const DiagnosticResult({
    required this.checkName,
    required this.passed,
    required this.finding,
    required this.alertType,
    this.value,
    this.threshold,
  });
}

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {

  bool _isRunning  = false;
  bool _isComplete = false;

  // Each check goes through these phases:
  // 0 = waiting, 1 = running, 2 = complete
  final Map<String, int> _checkPhase = {
    'ping':      0,
    'mac_table': 0,
    'cpu':       0,
    'memory':    0,
    'interface': 0,
    'bandwidth': 0,
  };

  final List<DiagnosticResult> _results = [];

  // Simulated MAC table data — this is the core of today's scenario
  int    _macTableCurrent = 0;
  int    _macTableMax     = 1000;
  double _macTablePct     = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runFullDiagnostic();
    });
  }

  Future<void> _runFullDiagnostic() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args is! DeviceModel) return;
    final device = args;

    setState(() {
      _isRunning  = true;
      _isComplete = false;
      _results.clear();
      _checkPhase.updateAll((key, _) => 0);
    });

    // Run each check sequentially with a delay between them
    // to simulate real network queries

    await _runPingCheck(device);
    await _runMacTableCheck(device);
    await _runCpuCheck(device);
    await _runMemoryCheck(device);
    await _runInterfaceCheck(device);
    await _runBandwidthCheck(device);

    setState(() {
      _isRunning  = false;
      _isComplete = true;
    });
  }

  // ── Individual Checks ─────────────────────────────────────────────────────

  Future<void> _runPingCheck(DeviceModel device) async {
    _setPhase('ping', 1);
    await Future.delayed(const Duration(milliseconds: 900));

    bool   passed;
    String finding;
    double latency = 0;

    if (device.status == AppConstants.statusOffline) {
      passed  = false;
      finding = 'Device is completely unreachable. 10/10 pings timed out.';
      latency = 0;
    } else if (device.status == AppConstants.statusDegraded) {
      passed  = false;
      finding = 'High latency detected. Average: 245ms (threshold: 200ms). '
          '2/10 packets lost.';
      latency = 245;
    } else {
      passed  = true;
      finding = 'Device responding normally. Average latency: 12ms. '
          '0/10 packets lost.';
      latency = 12;
    }

    _addResult(DiagnosticResult(
      checkName: 'ICMP Ping Test',
      passed:    passed,
      finding:   finding,
      alertType: passed ? '' : (latency == 0 ? 'device_offline' : 'high_latency'),
      value:     latency,
      threshold: 200,
    ));
    _setPhase('ping', 2);
  }

  Future<void> _runMacTableCheck(DeviceModel device) async {
    _setPhase('mac_table', 1);
    await Future.delayed(const Duration(milliseconds: 1100));

    // MAC table check is most important for OLT devices
    // but we run it on all devices for completeness
    bool   passed;
    String finding;
    String alertType = '';

    if (device.deviceType == 'olt') {
      // Simulate OLT with a nearly full MAC table
      // This is the core of our scenario — 873 out of 1000 entries used
      _macTableCurrent = 873;
      _macTableMax     = 1000;
      _macTablePct     = (_macTableCurrent / _macTableMax) * 100;

      if (_macTablePct >= 95) {
        passed    = false;
        alertType = 'mac_table_overflow';
        finding   = 'CRITICAL: MAC table at ${_macTablePct.toStringAsFixed(1)}% capacity '
            '($_macTableCurrent/$_macTableMax entries). '
            'New customers cannot connect. Immediate action required.';
      } else if (_macTablePct >= 85) {
        passed    = false;
        alertType = 'mac_table_overflow';
        finding   = 'WARNING: MAC table at ${_macTablePct.toStringAsFixed(1)}% capacity '
            '($_macTableCurrent/$_macTableMax entries). '
            'Risk of disconnections. Action required soon.';
      } else if (_macTablePct >= 70) {
        passed    = false;
        alertType = 'mac_table_warning';
        finding   = 'NOTICE: MAC table at ${_macTablePct.toStringAsFixed(1)}% capacity '
            '($_macTableCurrent/$_macTableMax entries). '
            'Monitor closely. Plan maintenance.';
      } else {
        passed  = true;
        finding = 'MAC table healthy at ${_macTablePct.toStringAsFixed(1)}% capacity '
            '($_macTableCurrent/$_macTableMax entries).';
      }
    } else {
      // Non-OLT devices — simulate a healthy MAC table
      _macTableCurrent = 124;
      _macTableMax     = 8192;
      _macTablePct     = (_macTableCurrent / _macTableMax) * 100;
      passed  = true;
      finding = 'MAC table healthy. '
          '$_macTableCurrent/$_macTableMax entries used '
          '(${_macTablePct.toStringAsFixed(1)}%).';
    }

    _addResult(DiagnosticResult(
      checkName: 'MAC Address Table',
      passed:    passed,
      finding:   finding,
      alertType: alertType,
      value:     _macTablePct,
      threshold: 85,
    ));
    _setPhase('mac_table', 2);
  }

  Future<void> _runCpuCheck(DeviceModel device) async {
    _setPhase('cpu', 1);
    await Future.delayed(const Duration(milliseconds: 800));

    double cpu;
    bool   passed;
    String finding;

    if (device.status == AppConstants.statusDegraded) {
      cpu     = 78.0;
      passed  = false;
      finding = 'CPU usage elevated at ${cpu.toStringAsFixed(0)}% '
          '(threshold: 80%). Monitor closely.';
    } else if (device.status == AppConstants.statusOffline) {
      cpu     = 0;
      passed  = false;
      finding = 'CPU data unavailable — device unreachable.';
    } else {
      cpu     = 34.0;
      passed  = true;
      finding = 'CPU usage normal at ${cpu.toStringAsFixed(0)}%.';
    }

    _addResult(DiagnosticResult(
      checkName: 'CPU Utilisation',
      passed:    passed,
      finding:   finding,
      alertType: passed ? '' : 'high_cpu',
      value:     cpu,
      threshold: 80,
    ));
    _setPhase('cpu', 2);
  }

  Future<void> _runMemoryCheck(DeviceModel device) async {
    _setPhase('memory', 1);
    await Future.delayed(const Duration(milliseconds: 700));

    double memory;
    bool   passed;
    String finding;

    if (device.status == AppConstants.statusDegraded) {
      memory  = 85.0;
      passed  = false;
      finding = 'Memory usage critical at ${memory.toStringAsFixed(0)}% '
          '(threshold: 85%). Risk of instability.';
    } else if (device.status == AppConstants.statusOffline) {
      memory  = 0;
      passed  = false;
      finding = 'Memory data unavailable — device unreachable.';
    } else {
      memory  = 52.0;
      passed  = true;
      finding = 'Memory usage normal at ${memory.toStringAsFixed(0)}%.';
    }

    _addResult(DiagnosticResult(
      checkName: 'Memory Usage',
      passed:    passed,
      finding:   finding,
      alertType: passed ? '' : 'high_memory',
      value:     memory,
      threshold: 85,
    ));
    _setPhase('memory', 2);
  }

  Future<void> _runInterfaceCheck(DeviceModel device) async {
    _setPhase('interface', 1);
    await Future.delayed(const Duration(milliseconds: 900));

    int    errors;
    bool   passed;
    String finding;

    if (device.status == AppConstants.statusDegraded) {
      errors  = 24;
      passed  = false;
      finding = '$errors interface errors detected in the last polling cycle. '
          'Possible physical layer issue.';
    } else if (device.status == AppConstants.statusOffline) {
      errors  = 0;
      passed  = false;
      finding = 'Interface data unavailable — device unreachable.';
    } else {
      errors  = 0;
      passed  = true;
      finding = 'All interfaces clean. Zero errors detected.';
    }

    _addResult(DiagnosticResult(
      checkName: 'Interface Errors',
      passed:    passed,
      finding:   finding,
      alertType: passed ? '' : 'interface_error',
      value:     errors.toDouble(),
      threshold: 10,
    ));
    _setPhase('interface', 2);
  }

  Future<void> _runBandwidthCheck(DeviceModel device) async {
    _setPhase('bandwidth', 1);
    await Future.delayed(const Duration(milliseconds: 600));

    bool   passed;
    String finding;
    double utilisation;

    if (device.status == AppConstants.statusOffline) {
      passed      = false;
      utilisation = 0;
      finding     = 'Bandwidth data unavailable — device unreachable.';
    } else {
      utilisation = device.status == AppConstants.statusDegraded ? 72 : 38;
      passed      = utilisation < 80;
      finding     = passed
          ? 'Bandwidth utilisation normal at '
              '${utilisation.toStringAsFixed(0)}%.'
          : 'Bandwidth utilisation high at '
              '${utilisation.toStringAsFixed(0)}% — near saturation.';
    }

    _addResult(DiagnosticResult(
      checkName: 'Bandwidth Utilisation',
      passed:    passed,
      finding:   finding,
      alertType: passed ? '' : 'high_latency',
      value:     utilisation,
      threshold: 80,
    ));
    _setPhase('bandwidth', 2);
  }

  // ── Helper methods ────────────────────────────────────────────────────────

  void _setPhase(String key, int phase) {
    setState(() => _checkPhase[key] = phase);
  }

  void _addResult(DiagnosticResult result) {
    setState(() => _results.add(result));
  }

  List<DiagnosticResult> get _failedChecks =>
      _results.where((r) => !r.passed && r.alertType.isNotEmpty).toList();

  bool get _overallPassed => _failedChecks.isEmpty;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args is! DeviceModel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic')),
        body: const Center(child: Text('No device selected.')),
      );
    }
    final device = args;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Full Diagnostic'),
        actions: [
          if (_isComplete)
            TextButton(
              onPressed: _runFullDiagnostic,
              child: const Text('Re-run',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Target Device ──────────────────────────────────────────
            _buildDeviceCard(device),
            const SizedBox(height: 16),

            // ── Overall Progress ───────────────────────────────────────
            _buildProgressCard(),
            const SizedBox(height: 16),

            // ── Check Items ────────────────────────────────────────────
            const Text(
              'Checks',
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.bold,
                color:      AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            _buildCheckRow('ping',      'ICMP Ping Test',         Icons.network_ping),
            _buildCheckRow('mac_table', 'MAC Address Table',      Icons.table_chart_outlined),
            _buildCheckRow('cpu',       'CPU Utilisation',        Icons.memory),
            _buildCheckRow('memory',    'Memory Usage',           Icons.storage),
            _buildCheckRow('interface', 'Interface Errors',       Icons.cable),
            _buildCheckRow('bandwidth', 'Bandwidth Utilisation',  Icons.speed),

            // ── MAC Table Detail (shown when OLT and check complete) ───
            if (_checkPhase['mac_table'] == 2 &&
                _results.any((r) => r.checkName == 'MAC Address Table'))
              _buildMacTableDetail(device),

            const SizedBox(height: 16),

            // ── Summary and Actions ─────────────────────────────────────
            if (_isComplete) ...[
              _buildSummaryCard(device),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding:    const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(AppUtils.deviceTypeIcon(device.deviceType),
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   15,
                        color:      AppColors.textPrimary)),
                Text('${device.ipAddress}  ·  '
                    '${AppUtils.deviceTypeLabel(device.deviceType)}',
                    style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textSecondary)),
              ],
            ),
          ),
          if (_isRunning)
            const SizedBox(
              width:  18,
              height: 18,
              child:  CircularProgressIndicator(strokeWidth: 2),
            ),
          if (_isComplete)
            Icon(
              _overallPassed ? Icons.check_circle : Icons.cancel,
              color: _overallPassed ? AppColors.online : AppColors.offline,
              size: 22,
            ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final completed = _checkPhase.values.where((v) => v == 2).length;
    final total     = _checkPhase.length;
    final progress  = completed / total;

    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isComplete
                    ? 'Diagnostic Complete'
                    : _isRunning
                        ? 'Running checks...'
                        : 'Ready',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textPrimary,
                ),
              ),
              Text(
                '$completed / $total checks',
                style: const TextStyle(
                  fontSize: 13,
                  color:    AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            progress,
              minHeight:        8,
              backgroundColor:  AppColors.primarySurface,
              valueColor:       AlwaysStoppedAnimation<Color>(
                _isComplete && !_overallPassed
                    ? AppColors.offline
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(
      String key, String label, IconData icon) {
    final phase  = _checkPhase[key] ?? 0;

    // Find the result for this check if it exists
    final result = _results.cast<DiagnosticResult?>().firstWhere(
          (r) => r?.checkName == label,
          orElse: () => null,
        );

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result == null
              ? AppColors.divider
              : result.passed
                  ? AppColors.online.withOpacity(0.3)
                  : AppColors.offline.withOpacity(0.4),
          width: result != null && !result.passed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Check icon
              Container(
                padding:    const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: result == null
                      ? AppColors.primarySurface
                      : result.passed
                          ? AppColors.onlineLight
                          : AppColors.offlineLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size:  16,
                    color: result == null
                        ? AppColors.primary
                        : result.passed
                            ? AppColors.online
                            : AppColors.offline),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize:   14,
                    color:      AppColors.textPrimary,
                  ),
                ),
              ),

              // Status indicator on the right
              if (phase == 0)
                Container(
                  width:  10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    shape: BoxShape.circle,
                  ),
                )
              else if (phase == 1)
                const SizedBox(
                  width:  18,
                  height: 18,
                  child:  CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  result?.passed ?? false
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: result?.passed ?? false
                      ? AppColors.online
                      : AppColors.offline,
                  size: 20,
                ),
            ],
          ),

          // Finding text — shown when check is complete
          if (phase == 2 && result != null) ...[
            const SizedBox(height: 8),
            Text(
              result.finding,
              style: TextStyle(
                fontSize: 13,
                color: result.passed
                    ? AppColors.textSecondary
                    : AppColors.offline,
                height: 1.4,
              ),
            ),

            // Value vs threshold bar for numeric results
            if (result.value != null &&
                result.threshold != null &&
                result.value! > 0) ...[
              const SizedBox(height: 8),
              _buildValueBar(result),
            ],
          ],
        ],
      ),
    );
  }

  /// Builds a visual bar showing current value vs threshold.
  Widget _buildValueBar(DiagnosticResult result) {
    final pct = (result.value! / (result.threshold! * 1.5)).clamp(0.0, 1.0);
    final thresholdPct = 1.0 / 1.5; // where the threshold sits on the bar

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${result.value!.toStringAsFixed(1)}'
              '${_unitForCheck(result.checkName)}',
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.bold,
                color: result.passed
                    ? AppColors.online
                    : AppColors.offline,
              ),
            ),
            Text(
              'Threshold: ${result.threshold!.toStringAsFixed(0)}'
              '${_unitForCheck(result.checkName)}',
              style: const TextStyle(
                fontSize: 11,
                color:    AppColors.textHint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            // Background bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:           pct,
                minHeight:       6,
                backgroundColor: AppColors.primarySurface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  result.passed ? AppColors.online : AppColors.offline,
                ),
              ),
            ),
            // Threshold marker line
            Positioned(
              left: MediaQuery.of(context).size.width *
                      thresholdPct *
                      0.78 -
                  1,
              top:  0,
              bottom: 0,
              child: Container(width: 2, color: AppColors.degraded),
            ),
          ],
        ),
      ],
    );
  }

  String _unitForCheck(String checkName) {
    if (checkName.contains('CPU') ||
        checkName.contains('Memory') ||
        checkName.contains('Bandwidth') ||
        checkName.contains('MAC')) return '%';
    if (checkName.contains('Ping') ||
        checkName.contains('Latency')) return 'ms';
    return '';
  }

  /// Detailed MAC table visualisation — shown for OLT devices.
  Widget _buildMacTableDetail(DeviceModel device) {
    if (device.deviceType != 'olt') return const SizedBox.shrink();

    final pct   = _macTablePct;
    final color = pct >= 95
        ? AppColors.offline
        : pct >= 85
            ? AppColors.severityHigh
            : pct >= 70
                ? AppColors.degraded
                : AppColors.online;

    return Container(
      margin:  const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_chart, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'MAC Address Table Detail',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:      color,
                  fontSize:   14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visual fill meter
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_macTableCurrent entries used',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:      color,
                            fontSize:   13,
                          ),
                        ),
                        Text(
                          '$_macTableMax maximum',
                          style: const TextStyle(
                            fontSize: 12,
                            color:    AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Segmented progress bar showing zones
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 14,
                        child:  Stack(
                          children: [
                            // Background — full bar in light colour
                            Container(
                              width:      double.infinity,
                              color:      AppColors.primarySurface,
                            ),
                            // Filled portion
                            FractionallySizedBox(
                              widthFactor: (pct / 100).clamp(0, 1),
                              child: Container(color: color),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Zone labels
                    Row(
                      children: [
                        _ZoneLabel('Safe\n0–70%',     AppColors.online),
                        _ZoneLabel('Warn\n70–85%',    AppColors.degraded),
                        _ZoneLabel('Critical\n85–95%',AppColors.severityHigh),
                        _ZoneLabel('Emergency\n95%+', AppColors.offline),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Percentage circle
              SizedBox(
                width:  64,
                height: 64,
                child:  Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value:           pct / 100,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeWidth: 7,
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.bold,
                        color:      color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Impact statement
          if (pct >= 70) ...[
            const SizedBox(height: 12),
            Container(
              padding:    const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_outlined, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pct >= 95
                          ? 'EMERGENCY: New customers cannot connect. '
                              'Existing customers at risk of disconnection. '
                              'Immediate action required.'
                          : pct >= 85
                              ? 'CRITICAL: New customer connections are '
                                  'failing. Existing customers may experience '
                                  'intermittent drops. Resolve within 1 hour.'
                              : 'WARNING: MAC table filling rapidly. '
                                  'Plan a maintenance window to clear entries '
                                  'and implement per-port MAC limits.',
                      style: TextStyle(
                        fontSize: 12,
                        color:    color,
                        height:   1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(DeviceModel device) {
    final failedCount  = _failedChecks.length;
    final passedCount  = _results.where((r) => r.passed).length;

    return Container(
      padding:    const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _overallPassed
            ? AppColors.onlineLight
            : AppColors.offlineLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _overallPassed
              ? AppColors.online.withOpacity(0.4)
              : AppColors.offline.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verdict
          Row(
            children: [
              Icon(
                _overallPassed ? Icons.check_circle : Icons.cancel,
                color: _overallPassed ? AppColors.online : AppColors.offline,
                size:  28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _overallPassed
                          ? 'All Checks Passed'
                          : '$failedCount Issue${failedCount > 1 ? "s" : ""} Found',
                      style: TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.bold,
                        color: _overallPassed
                            ? AppColors.online
                            : AppColors.offline,
                      ),
                    ),
                    Text(
                      '$passedCount of ${_results.length} checks passed',
                      style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // List of failed checks with troubleshoot buttons
          if (_failedChecks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Issues requiring attention:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color:      AppColors.textPrimary,
                fontSize:   14,
              ),
            ),
            const SizedBox(height: 8),

            ..._failedChecks.map((result) => Container(
                  margin:  const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.offline.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: AppColors.offline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.checkName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize:   13,
                            color:      AppColors.textPrimary,
                          ),
                        ),
                      ),

                      // Troubleshoot button for each failed check
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed(
                          AppConstants.troubleshootRoute,
                          arguments: {
                            'device':     device,
                            'alertType':  result.alertType,
                            'checkName':  result.checkName,
                            'value':      result.value,
                            'threshold':  result.threshold,
                          },
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:        AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Fix This',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 8),

            // Single button to troubleshoot the most critical issue
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(
                AppConstants.troubleshootRoute,
                arguments: {
                  'device':    device,
                  'alertType': _failedChecks.first.alertType,
                  'checkName': _failedChecks.first.checkName,
                  'value':     _failedChecks.first.value,
                  'threshold': _failedChecks.first.threshold,
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.offline,
                minimumSize:     const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon:  const Icon(Icons.build_outlined),
              label: const Text(
                'Start Troubleshooting',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zone label widget for the MAC table bar.
class _ZoneLabel extends StatelessWidget {
  final String label;
  final Color  color;
  const _ZoneLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(height: 3, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}