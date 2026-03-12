import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';

/// DiagnosticScreen simulates a live ICMP ping diagnostic against
/// the selected device. Sends 10 pings one by one with a visual
/// result for each, then shows a final pass/fail verdict card.
///
/// Receives a DeviceModel via route arguments:
///   Navigator.pushNamed(context, AppConstants.diagnosticRoute, arguments: device)
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  bool _isRunning  = false;
  bool _isComplete = false;
  int  _currentPing = 0;

  final List<_PingResult> _results = [];

  double? _avgLatency;
  double? _minLatency;
  double? _maxLatency;
  double? _packetLoss;

  static const int _totalPings = 10;

  // ── Traceroute state ──────────────────────────────────────────────────────
  bool _isTracerouting       = false;
  bool _tracerouteComplete   = false;
  final List<_TracerouteHop> _hops = [];

  // device is read lazily on first use because ModalRoute is not
  // available until the widget is fully mounted.
  DeviceModel? _device;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so ModalRoute.of(context) is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeviceModel) {
        setState(() => _device = args);
        _startDiagnostic(args);
      }
    });
  }

  Future<void> _startDiagnostic(DeviceModel device) async {
    setState(() {
      _isRunning   = true;
      _isComplete  = false;
      _currentPing = 0;
      _results.clear();
      _avgLatency  = null;
      _minLatency  = null;
      _maxLatency  = null;
      _packetLoss  = null;
    });

    final bool isOffline  = device.status == AppConstants.statusOffline;
    final bool isDegraded = device.status == AppConstants.statusDegraded;

    for (int i = 1; i <= _totalPings; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      _PingResult result;

      if (isOffline) {
        result = _PingResult(
          sequence:  i,
          success:   false,
          latencyMs: null,
          message:   'Request timeout',
        );
      } else if (isDegraded) {
        final failed  = i == 3 || i == 7;
        final latency = failed ? null : 200.0 + (i * 12.5);
        result = _PingResult(
          sequence:  i,
          success:   !failed,
          latencyMs: latency,
          message:   failed
              ? 'Request timeout'
              : 'Reply from ${device.ipAddress}: time=${latency!.toStringAsFixed(1)}ms',
        );
      } else {
        final latency = 8.0 + (i % 3) * 4.2;
        result = _PingResult(
          sequence:  i,
          success:   true,
          latencyMs: latency,
          message:   'Reply from ${device.ipAddress}: time=${latency.toStringAsFixed(1)}ms',
        );
      }

      setState(() {
        _results.add(result);
        _currentPing = i;
      });
    }

    _computeSummary();
    setState(() {
      _isRunning  = false;
      _isComplete = true;
    });

    // Automatically start traceroute after ping
    _startTraceroute(device);
  }

  // ── Traceroute simulation ─────────────────────────────────────────────────

  Future<void> _startTraceroute(DeviceModel device) async {
    setState(() {
      _isTracerouting     = true;
      _tracerouteComplete = false;
      _hops.clear();
    });

    final rng   = Random(device.ipAddress.hashCode);
    final isOff = device.status == AppConstants.statusOffline;

    final hopCount   = isOff ? 4 : 4 + rng.nextInt(4); // 4-7 hops
    final hostnames  = [
      'gateway.local',
      'core-sw01.isp.net',
      'agg-rtr02.isp.net',
      'pe-rtr01.region.net',
      'bras01.pop.net',
      'dist-sw03.site.net',
      device.ipAddress,
    ];

    for (int i = 0; i < hopCount; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final isLast   = i == hopCount - 1;
      final hostname = i < hostnames.length ? hostnames[i] : '10.${rng.nextInt(255)}.${rng.nextInt(255)}.1';
      final ip       = isLast ? device.ipAddress : '10.${10 + i}.${rng.nextInt(255)}.1';

      double? latency;
      if (isOff && isLast) {
        latency = null; // timeout at final hop
      } else {
        latency = 1.0 + i * (3.0 + rng.nextDouble() * 5.0);
        if (device.status == AppConstants.statusDegraded) {
          latency += 50.0 + rng.nextDouble() * 80.0;
        }
      }

      setState(() {
        _hops.add(_TracerouteHop(
          hop:      i + 1,
          hostname: hostname,
          ip:       ip,
          latencyMs: latency,
        ));
      });
    }

    setState(() {
      _isTracerouting     = false;
      _tracerouteComplete = true;
    });
  }

  void _computeSummary() {
    final successful = _results.where((r) => r.success).toList();
    final latencies  = successful.map((r) => r.latencyMs!).toList();

    _packetLoss = ((_totalPings - successful.length) / _totalPings) * 100;
    if (latencies.isNotEmpty) {
      _avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      _minLatency = latencies.reduce((a, b) => a < b ? a : b);
      _maxLatency = latencies.reduce((a, b) => a > b ? a : b);
    }
  }

  bool get _passed =>
      (_packetLoss ?? 100) <= 5 && (_avgLatency ?? 999) <= 200;

  @override
  Widget build(BuildContext context) {
    // Guard: if device hasn't arrived yet show a loader.
    if (_device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final device = _device!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diagnostic'),
        actions: [
          if (_isComplete)
            TextButton(
              onPressed: () => _startDiagnostic(device),
              child: const Text('Run Again',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Target device card ───────────────────────────────────────
            _buildTargetCard(device),
            const SizedBox(height: 16),

            // ── Progress header ──────────────────────────────────────────
            _buildProgressHeader(),
            const SizedBox(height: 12),

            // ── Live ping chart ──────────────────────────────────────────
            if (_results.isNotEmpty)
              _buildLiveChart(),
            if (_results.isNotEmpty) const SizedBox(height: 16),

            // ── Ping results table ───────────────────────────────────────
            _buildPingResults(),
            const SizedBox(height: 16),

            // ── Summary card — shown only after all pings finish ─────────
            if (_isComplete) ...[
              _buildSummaryCard(device),
              const SizedBox(height: 16),
            ],

            // ── Traceroute section ───────────────────────────────────────
            if (_isTracerouting || _tracerouteComplete) ...[
              _buildTracerouteSection(),
              const SizedBox(height: 32),
            ] else if (_isComplete) ...[
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ── Target card ──────────────────────────────────────────────────────────

  Widget _buildTargetCard(DeviceModel device) {
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05), blurRadius: 6)],
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
                Text(device.name, style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize:   15,
                  color:      AppColors.textPrimary,
                )),
                Text(device.ipAddress, style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (_isRunning)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  // ── Progress header ───────────────────────────────────────────────────────

  Widget _buildProgressHeader() {
    return Row(
      children: [
        const Text('Ping Results', style: TextStyle(
          fontSize:   16,
          fontWeight: FontWeight.bold,
          color:      AppColors.textPrimary,
        )),
        const Spacer(),
        Text('$_currentPing / $_totalPings', style: const TextStyle(
          fontSize:   14,
          color:      AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        )),
      ],
    );
  }

  // ── Ping results table ────────────────────────────────────────────────────

  Widget _buildPingResults() {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: const [
                SizedBox(width: 28),
                SizedBox(
                  width: 30,
                  child: Text('Seq', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color:    AppColors.textSecondary)),
                ),
                Expanded(child: Text('Result', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color:    AppColors.textSecondary))),
                Text('Latency', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color:    AppColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(_totalPings, (index) {
            final seq = index + 1;
            if (index < _results.length) {
              return _PingRow(result: _results[index]);
            }
            if (seq == _currentPing + 1 && _isRunning) {
              return _PingRowPending(sequence: seq);
            }
            return _PingRowEmpty(sequence: seq);
          }),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(DeviceModel device) {
    return Container(
      padding:    const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _passed ? AppColors.onlineLight : AppColors.offlineLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _passed
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
                _passed ? Icons.check_circle : Icons.cancel,
                color: _passed ? AppColors.online : AppColors.offline,
                size:  28,
              ),
              const SizedBox(width: 10),
              Text(
                _passed ? 'Diagnostic Passed' : 'Diagnostic Failed',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                  color: _passed ? AppColors.online : AppColors.offline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              _StatBox(
                label: 'Avg Latency',
                value: _avgLatency != null
                    ? '${_avgLatency!.toStringAsFixed(1)} ms' : 'N/A',
                good:  (_avgLatency ?? 999) <= 200,
              ),
              const SizedBox(width: 10),
              _StatBox(
                label: 'Packet Loss',
                value: '${_packetLoss!.toStringAsFixed(0)}%',
                good:  (_packetLoss ?? 100) <= 5,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatBox(
                label: 'Min Latency',
                value: _minLatency != null
                    ? '${_minLatency!.toStringAsFixed(1)} ms' : 'N/A',
                good:  true,
              ),
              const SizedBox(width: 10),
              _StatBox(
                label: 'Max Latency',
                value: _maxLatency != null
                    ? '${_maxLatency!.toStringAsFixed(1)} ms' : 'N/A',
                good:  (_maxLatency ?? 999) <= 300,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recommendation
          Container(
            padding:    const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16,
                    color: _passed ? AppColors.online : AppColors.offline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _recommendation(device),
                    style: TextStyle(
                      fontSize: 13,
                      color: _passed ? AppColors.online : AppColors.textPrimary,
                      height:   1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Troubleshoot button — only shown on failure
          if (!_passed) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(
                AppConstants.troubleshootRoute,
                arguments: device,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.offline,
                minimumSize:     const Size(double.infinity, 48),
              ),
              icon:  const Icon(Icons.build_outlined),
              label: const Text('Start Troubleshooting',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Live ping chart ─────────────────────────────────────────────────────

  Widget _buildLiveChart() {
    final successResults = _results.where((r) => r.success).toList();
    final spots = successResults.map((r) =>
        FlSpot(r.sequence.toDouble(), r.latencyMs ?? 0)).toList();

    // Compute running stats displayed inside the chart card
    final latencies = successResults.map((r) => r.latencyMs!).toList();
    final runMin = latencies.isNotEmpty
        ? latencies.reduce((a, b) => a < b ? a : b) : 0.0;
    final runMax = latencies.isNotEmpty
        ? latencies.reduce((a, b) => a > b ? a : b) : 0.0;
    final runAvg = latencies.isNotEmpty
        ? latencies.reduce((a, b) => a + b) / latencies.length : 0.0;
    final runLoss = ((_results.length - successResults.length) /
        _results.length * 100);

    final maxY = (runMax + 40).clamp(50.0, 600.0);

    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart header with live stats
          Row(
            children: [
              const Icon(Icons.show_chart, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('Live Latency', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              if (_isRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 8, height: 8,
                        child: CircularProgressIndicator(strokeWidth: 1.5)),
                      SizedBox(width: 6),
                      Text('LIVE', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Mini stat row
          Row(
            children: [
              _MiniStat(label: 'Avg', value: '${runAvg.toStringAsFixed(1)} ms'),
              _MiniStat(label: 'Min', value: '${runMin.toStringAsFixed(1)} ms'),
              _MiniStat(label: 'Max', value: '${runMax.toStringAsFixed(1)} ms'),
              _MiniStat(label: 'Loss', value: '${runLoss.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 12),
          // Chart
          SizedBox(
            height: 160,
            child: spots.isEmpty
                ? const Center(child: Text('Waiting for successful pings...',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true, drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: AppColors.divider, strokeWidth: 0.5),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 36,
                          getTitlesWidget: (v, _) => Text(
                            '${v.toInt()}',
                            style: const TextStyle(
                              fontSize: 10, color: AppColors.textHint),
                          ),
                        )),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 20,
                          getTitlesWidget: (v, _) => Text(
                            '#${v.toInt()}',
                            style: const TextStyle(
                              fontSize: 10, color: AppColors.textHint),
                          ),
                        )),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 1, maxX: _totalPings.toDouble(),
                      minY: 0, maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots:    spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color:    AppColors.primary,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                                  radius:      3,
                                  color:       AppColors.primary,
                                  strokeWidth: 1.5,
                                  strokeColor: Colors.white,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show:  true,
                            color: AppColors.primary.withOpacity(0.08),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primary.withOpacity(0.9),
                          getTooltipItems: (spots) => spots.map((s) =>
                              LineTooltipItem(
                                '${s.y.toStringAsFixed(1)} ms',
                                const TextStyle(
                                    color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              )).toList(),
                        ),
                      ),
                    ),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Traceroute section ──────────────────────────────────────────────────

  Widget _buildTracerouteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('Traceroute', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
            const Spacer(),
            if (_isTracerouting)
              const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            if (_tracerouteComplete)
              Text('${_hops.length} hops', style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: Column(
            children: [
              ..._hops.asMap().entries.map((entry) {
                final i   = entry.key;
                final hop = entry.value;
                final isLast = i == _hops.length - 1 && _tracerouteComplete;
                return _TracerouteRow(hop: hop, isLast: isLast);
              }),
              if (_isTracerouting)
                _TracerouteRowPending(hop: _hops.length + 1),
            ],
          ),
        ),
      ],
    );
  }

  String _recommendation(DeviceModel device) {
    if (_passed) {
      return '${device.name} is responding normally. '
          'Connectivity and latency are within acceptable thresholds.';
    }
    if ((_packetLoss ?? 0) == 100) {
      return '${device.name} is completely unreachable. '
          'Check physical connections, power status, and upstream link.';
    }
    if ((_packetLoss ?? 0) > 5) {
      return 'Significant packet loss detected on ${device.name}. '
          'This may indicate congestion, a faulty cable, or interference.';
    }
    return 'High latency detected on ${device.name}. '
        'Check bandwidth utilisation and upstream link quality.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

class _PingResult {
  final int     sequence;
  final bool    success;
  final double? latencyMs;
  final String  message;
  const _PingResult({
    required this.sequence,
    required this.success,
    required this.latencyMs,
    required this.message,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Row widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PingRow extends StatelessWidget {
  final _PingResult result;
  const _PingRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(
            color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.cancel,
            color: result.success ? AppColors.online : AppColors.offline,
            size:  18,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text('#${result.sequence}', style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(result.message, style: TextStyle(
              fontSize:   12,
              color:      result.success
                  ? AppColors.textPrimary : AppColors.offline,
              fontFamily: 'monospace',
            )),
          ),
          Text(
            result.latencyMs != null
                ? '${result.latencyMs!.toStringAsFixed(1)} ms' : '---',
            style: TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color: result.success ? AppColors.online : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _PingRowPending extends StatelessWidget {
  final int sequence;
  const _PingRowPending({required this.sequence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(
            color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text('#$sequence', style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary)),
          ),
          const Expanded(child: Text('Sending...', style: TextStyle(
            fontSize: 12, color: AppColors.textHint,
            fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }
}

class _PingRowEmpty extends StatelessWidget {
  final int sequence;
  const _PingRowEmpty({required this.sequence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(
            color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width:      18, height: 18,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 30,
            child: Text('#$sequence', style: const TextStyle(
              fontSize: 13, color: AppColors.textHint)),
          ),
          const Expanded(child: Text('Waiting...', style: TextStyle(
            fontSize: 12, color: AppColors.textHint))),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool   good;
  const _StatBox({required this.label, required this.value, required this.good});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:    const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.bold,
              color: good ? AppColors.online : AppColors.offline,
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini stat chip for the live chart header
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(
            fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Traceroute data & widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TracerouteHop {
  final int     hop;
  final String  hostname;
  final String  ip;
  final double? latencyMs;
  const _TracerouteHop({
    required this.hop,
    required this.hostname,
    required this.ip,
    required this.latencyMs,
  });
}

class _TracerouteRow extends StatelessWidget {
  final _TracerouteHop hop;
  final bool           isLast;
  const _TracerouteRow({required this.hop, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final timedOut = hop.latencyMs == null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: timedOut
                        ? AppColors.offlineLight
                        : isLast
                            ? AppColors.onlineLight
                            : AppColors.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: timedOut
                          ? AppColors.offline
                          : isLast
                              ? AppColors.online
                              : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text('${hop.hop}', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: timedOut ? AppColors.offline
                          : isLast ? AppColors.online : AppColors.primary,
                    )),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hop.hostname, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: timedOut ? AppColors.offline : AppColors.textPrimary,
                  )),
                  const SizedBox(height: 2),
                  Text(hop.ip, style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  )),
                ],
              ),
            ),
          ),
          // Latency
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 14, 0),
            child: Text(
              timedOut ? '* * *' : '${hop.latencyMs!.toStringAsFixed(1)} ms',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: timedOut ? AppColors.offline : AppColors.online,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TracerouteRowPending extends StatelessWidget {
  final int hop;
  const _TracerouteRowPending({required this.hop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Center(
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 2),
                ),
                child: const Center(
                  child: SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('Hop $hop — probing...', style: const TextStyle(
              fontSize: 12, fontStyle: FontStyle.italic,
              color: AppColors.textHint)),
          ),
        ],
      ),
    );
  }
}
