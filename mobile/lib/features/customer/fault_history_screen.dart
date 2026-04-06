import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/alert_model.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FaultHistoryProvider
// ─────────────────────────────────────────────────────────────────────────────

class FaultHistoryProvider extends ChangeNotifier {
  bool    _isLoading = false;
  String? _error;
  String  _filter   = 'all'; // all | active | resolved

  bool    get isLoading => _isLoading;
  String? get error     => _error;
  String  get filter    => _filter;

  List<AlertModel> _allFaults = [];

  List<AlertModel> get faults {
    switch (_filter) {
      case 'active':   return _allFaults.where((a) => !a.isResolved).toList();
      case 'resolved': return _allFaults.where((a) =>  a.isResolved).toList();
      default:         return _allFaults;
    }
  }

  // Stats for the summary header
  int get totalFaults    => _allFaults.length;
  int get resolvedFaults => _allFaults.where((a) => a.isResolved).length;
  int get activeFaults   => _allFaults.where((a) => !a.isResolved).length;

  void setFilter(String f) {
    _filter = f;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allFaults = await ApiClient.getMyAlerts();
      _error = null;
    } catch (e) {
      _error = 'Failed to load fault history.';
      if (e.toString().isNotEmpty) {
        _error = e.toString();
      }
    }
    _isLoading = false;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FaultHistoryScreen
// ─────────────────────────────────────────────────────────────────────────────

class FaultHistoryScreen extends StatefulWidget {
  const FaultHistoryScreen({super.key});

  @override
  State<FaultHistoryScreen> createState() => _FaultHistoryScreenState();
}

class _FaultHistoryScreenState extends State<FaultHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaultHistoryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FaultHistoryProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Service History'),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (provider.error != null)
                      _buildErrorBanner(provider),

                    // ── Summary stats header ─────────────────────────────
                    _buildSummaryHeader(provider),

                    // ── Filter chips ─────────────────────────────────────
                    _buildFilterRow(provider),

                    // ── Fault list ───────────────────────────────────────
                    Expanded(
                      child: provider.faults.isEmpty
                          ? _buildEmptyState(provider.filter)
                          : RefreshIndicator(
                              onRefresh: provider.load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                                itemCount: provider.faults.length,
                                itemBuilder: (context, i) {
                                  final fault = provider.faults[i];
                                  return _FaultCard(
                                    fault:   fault,
                                    onTap:   () => _showFaultDetail(context, fault),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSummaryHeader(FaultHistoryProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          _StatBox(
            label: 'Total',
            value: provider.totalFaults.toString(),
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'Active',
            value: provider.activeFaults.toString(),
            color: provider.activeFaults > 0
                ? AppColors.primary
                : AppColors.textHintOf(context),
          ),
          const SizedBox(width: 10),
          _StatBox(
            label: 'Resolved',
            value: provider.resolvedFaults.toString(),
            color: AppColors.primaryDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(FaultHistoryProvider provider) {
    final filterKeys   = ['all',      'active',  'resolved'];
    final filterLabels = ['All',      'Active',  'Resolved'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: List.generate(filterKeys.length, (i) {
          final key      = filterKeys[i];
          final label    = filterLabels[i];
          final selected = provider.filter == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => provider.setFilter(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:        selected ? AppColors.primary : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.dividerOf(context)),
                ),
                child: Text(label, style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondaryOf(context),
                )),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 56, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            filter == 'active' ? 'No active faults' : 'No history yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your service has been running without issues.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(FaultHistoryProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.error ?? 'Failed to load fault history.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          TextButton(
            onPressed: provider.load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showFaultDetail(BuildContext context, AlertModel fault) {
    showModalBottomSheet<void>(
      context:     context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FaultDetailSheet(fault: fault),
    );
  }
}

// ── _FaultCard ────────────────────────────────────────────────────────────────

class _FaultCard extends StatelessWidget {
  final AlertModel   fault;
  final VoidCallback onTap;
  const _FaultCard({required this.fault, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final resolved = fault.isResolved;
    final statusColor = AppColors.primary;

    // Duration of the fault (if resolved)
    String? duration;
    if (resolved && fault.resolvedAt != null) {
      final start = DateTime.tryParse(fault.triggeredAt);
      final end   = DateTime.tryParse(fault.resolvedAt!);
      if (start != null && end != null) {
        final diff = end.difference(start);
        if (diff.inHours > 0) {
          duration = '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
        } else {
          duration = '${diff.inMinutes}m';
        }
      }
    }

    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.dividerOf(context),
            width: 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left colored indicator
            Container(
              width:  4,
              height: 50,
              decoration: BoxDecoration(
                color:        statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _friendlyTitle(fault.alertType),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      _StatusBadge(resolved: resolved),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _friendlyMessage(fault.message),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondaryOf(context),
                      height: 1.45,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: AppColors.textHintOf(context)),
                      const SizedBox(width: 4),
                      Text(
                        AppUtils.timeAgo(fault.triggeredAt),
                        style: TextStyle(fontSize: 11, color: AppColors.textHintOf(context)),
                      ),
                      if (duration != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.timer_outlined, size: 12, color: AppColors.textHintOf(context)),
                        const SizedBox(width: 4),
                        Text(
                          'Lasted $duration',
                          style: TextStyle(fontSize: 11, color: AppColors.textHintOf(context)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHintOf(context), size: 20),
          ],
        ),
      ),
    );
  }

  String _friendlyTitle(String type) {
    switch (type) {
      case 'device_offline':  return 'Internet Outage';
      case 'high_latency':    return 'Slow Connection';
      case 'packet_loss':     return 'Unstable Connection';
      case 'high_cpu':        return 'Router Overloaded';
      case 'interface_error': return 'Network Interface Error';
      default: return type.replaceAll('_', ' ');
    }
  }

  String _friendlyMessage(String msg) {
    // Convert technical message to plain English
    return msg
        .replaceAll('SNMP', 'router check')
        .replaceAll('ICMP', 'network test')
        .replaceAll('ms', ' milliseconds')
        .replaceAll('CPU', 'processor');
  }
}

class _StatusBadge extends StatelessWidget {
  final bool resolved;
  const _StatusBadge({required this.resolved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        resolved ? 'Resolved' : 'Active',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Fault Detail Bottom Sheet ──────────────────────────────────────────────────

class _FaultDetailSheet extends StatelessWidget {
  final AlertModel fault;
  const _FaultDetailSheet({required this.fault});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize:     0.4,
      maxChildSize:     0.9,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          controller: controller,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerOf(context), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Severity badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        AppColors.primarySurfaceOf(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    fault.severity.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                _StatusBadge(resolved: fault.isResolved),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(_friendlyTitle(fault.alertType), style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Text(_friendlyMessage(fault.message), style: TextStyle(
              fontSize: 13.5, color: AppColors.textSecondaryOf(context), height: 1.5)),
            const Divider(height: 24),

            // Timeline
            _DetailRow(label: 'Started', value: AppUtils.formatDateTime(fault.triggeredAt)),
            if (fault.resolvedAt != null)
              _DetailRow(label: 'Resolved', value: AppUtils.formatDateTime(fault.resolvedAt!)),
            _DetailRow(label: 'Device', value: fault.deviceName),
            const Divider(height: 24),

            // What happened — plain English explanation
            Text('What happened?', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
            const SizedBox(height: 8),
            Text(
              _whatHappened(fault.alertType),
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondaryOf(context), height: 1.6),
            ),
            const SizedBox(height: 14),

            // What was done
            if (fault.isResolved) ...[
              Text('How was it fixed?', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
              const SizedBox(height: 8),
              Text(
                _howFixed(fault.alertType),
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondaryOf(context), height: 1.6),
              ),
            ] else ...[
              Container(
                padding:    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurfaceOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.engineering, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Our technical team has been notified and is working to resolve this issue.',
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _friendlyTitle(String type) {
    switch (type) {
      case 'device_offline':  return 'Internet Outage';
      case 'high_latency':    return 'Slow Connection';
      case 'packet_loss':     return 'Unstable Connection';
      case 'high_cpu':        return 'Router Overloaded';
      case 'interface_error': return 'Network Interface Error';
      default: return type.replaceAll('_', ' ');
    }
  }

  String _friendlyMessage(String msg) {
    return msg.replaceAll('SNMP', 'router check').replaceAll('ICMP', 'network test').replaceAll('ms', ' ms');
  }

  String _whatHappened(String type) {
    switch (type) {
      case 'device_offline':
        return 'Your router stopped responding to our monitoring checks. This usually means the device lost power, the internet feed was interrupted, or the router needed a restart.';
      case 'high_latency':
        return 'Your connection was working, but the speed of communication between your router and our network was much slower than normal. This can cause websites to load slowly and video calls to freeze.';
      case 'packet_loss':
        return 'Some of the data travelling across your connection was getting lost before reaching its destination. This is like letters going missing in the post — it causes loading errors and buffering.';
      case 'high_cpu':
        return 'Your router\'s internal processor was working too hard. This can happen when many devices are connected at once, or if the router has been on for a long time without a restart.';
      case 'interface_error':
        return 'One of the connection ports on your router was reporting errors. This can be caused by a faulty cable, a loose connection, or a hardware issue with the router.';
      default:
        return 'Our monitoring system detected an anomaly with your connection that required attention.';
    }
  }

  String _howFixed(String type) {
    switch (type) {
      case 'device_offline':
        return 'Our system automatically detected the outage and alerted the technical team. The connection was restored once the equipment came back online.';
      case 'high_latency':
        return 'The latency returned to normal levels on its own. If congestion was the cause, it cleared as network load reduced.';
      case 'packet_loss':
        return 'The packet loss stopped and the connection stabilised. Our team monitored it until it was confirmed stable.';
      case 'high_cpu':
        return 'The router\'s processor load dropped back to normal. A remote restart may have been performed if needed.';
      default:
        return 'The issue was identified and resolved by our technical team.';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryOf(context))),
          ),
          Expanded(child: Text(value, style: TextStyle(
            fontSize: 13, color: AppColors.textPrimaryOf(context)))),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:    const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(
              fontSize: 12, color: AppColors.textSecondaryOf(context))),
          ],
        ),
      ),
    );
  }
}
