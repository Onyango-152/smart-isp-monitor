import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomerHomeProvider — drives the "My Service" screen
// ─────────────────────────────────────────────────────────────────────────────

class CustomerHomeProvider extends ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<DeviceModel> _myDevices    = [];
  int               _selectedIdx  = 0;
  MetricModel?      _myMetric     = null;
  List<AlertModel>  _recentAlerts = [];

  List<DeviceModel> get myDevices    => _myDevices;
  DeviceModel?      get myDevice     => _myDevices.isNotEmpty ? _myDevices[_selectedIdx] : null;
  int               get selectedIdx  => _selectedIdx;
  MetricModel?      get myMetric     => _myMetric;
  List<AlertModel>  get recentAlerts => _recentAlerts;

  void selectDevice(int idx) {
    if (idx >= 0 && idx < _myDevices.length) {
      _selectedIdx = idx;
      notifyListeners();
      _loadMetricForSelected();
    }
  }

  bool get serviceIsHealthy =>
      myDevice?.status == 'online' &&
      _recentAlerts.where((a) => !a.isResolved).isEmpty;

  String get serviceStatusLabel =>
      serviceIsHealthy ? 'Service is Healthy' : 'Service Issue Detected';

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiClient.getMyDevices(),
        ApiClient.getMyAlerts(),
      ]);
      _myDevices    = results[0] as List<DeviceModel>;
      final alerts  = results[1] as List<AlertModel>;

      if (_selectedIdx >= _myDevices.length) _selectedIdx = 0;

      await _loadMetricForSelected();

      _recentAlerts = alerts
          .where((a) => a.deviceId == myDevice?.id)
          .take(5)
          .toList();
    } catch (_) {
      // Keep stale data
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadMetricForSelected() async {
    final device = myDevice;
    if (device == null) return;
    try {
      final metrics = await ApiClient.getMetrics(deviceId: device.id);
      final sorted  = metrics..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      _myMetric = sorted.isNotEmpty ? sorted.first : null;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refresh() => load();
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomerHomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerHomeProvider>().load();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerHomeProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('My Service'),
            actions: [
              IconButton(
                icon:      const Icon(Icons.refresh),
                onPressed: provider.refresh,
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      _buildStatusCard(provider),
                      const SizedBox(height: 16),
                      if (provider.myDevices.length > 1)
                        _buildDeviceSelector(provider),
                      if (provider.myDevices.length > 1)
                        const SizedBox(height: 16),
                      _buildServiceSummary(provider),
                      const SizedBox(height: 16),
                      _buildKpiRow(provider),
                      const SizedBox(height: 18),
                      _buildIssueFocus(provider),
                      const SizedBox(height: 18),
                      _buildQuickActions(context),
                      const SizedBox(height: 18),
                      _buildRecentIssues(provider),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ── Status Card ───────────────────────────────────────────────────────────

  Widget _buildDeviceSelector(CustomerHomeProvider provider) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: provider.myDevices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final device   = provider.myDevices[i];
          final selected = i == provider.selectedIdx;
          return GestureDetector(
            onTap: () => provider.selectDevice(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.dividerOf(context),
                ),
              ),
              child: Text(
                device.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimaryOf(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(CustomerHomeProvider provider) {
    final healthy  = provider.serviceIsHealthy;
    final bgColor  = AppColors.primary;
    final icon     = healthy ? Icons.check_circle : Icons.warning_rounded;
    final endColor = AppColors.primaryDark;
    final subtitle = healthy
        ? 'Your internet connection is working normally.'
        : 'We have detected an issue with your service. Our team is working on it.';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: healthy ? 1.0 : _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgColor, endColor],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      bgColor.withOpacity(0.35),
              blurRadius: 16,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 56),
            const SizedBox(height: 12),
            Text(
              provider.serviceStatusLabel,
              style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                healthy ? 'No current issues' : 'Issue detected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color:    Colors.white.withOpacity(0.85),
                fontSize: 14,
                height:   1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Last checked: ${AppUtils.timeAgo(DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String())}',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Service Summary ─────────────────────────────────────────────────────-

  Widget _buildServiceSummary(CustomerHomeProvider provider) {
    final device = provider.myDevice;
    final name = device?.name ?? 'Your device';
    final ip = device?.ipAddress ?? 'Not linked yet';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySurfaceOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wifi_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ip,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          if (device != null) _StatusPill(status: device.status),
        ],
      ),
    );
  }

  // ── KPI Row ─────────────────────────────────────────────────────────────

  Widget _buildKpiRow(CustomerHomeProvider provider) {
    final metric = provider.myMetric;

    final latency = metric?.latencyMs != null
        ? '${metric!.latencyMs!.toStringAsFixed(0)} ms'
        : '-- ms';
    final loss = metric?.packetLossPct != null
        ? '${metric!.packetLossPct!.toStringAsFixed(1)}%'
        : '--%';
    final uptimePct = metric?.uptimeSeconds != null
        ? (metric!.uptimeSeconds! / 2592000 * 100).clamp(0.0, 100.0)
        : null;
    final uptime = uptimePct != null ? '${uptimePct.toStringAsFixed(1)}%' : '--%';

    return Row(
      children: [
        _KpiTile(
          label: 'Latency',
          value: latency,
          icon: Icons.speed_rounded,
        ),
        const SizedBox(width: 10),
        _KpiTile(
          label: 'Packet Loss',
          value: loss,
          icon: Icons.wifi_tethering_rounded,
        ),
        const SizedBox(width: 10),
        _KpiTile(
          label: 'Uptime',
          value: uptime,
          icon: Icons.timeline_rounded,
        ),
      ],
    );
  }

  // ── Issue focus card ─────────────────────────────────────────────────----

  Widget _buildIssueFocus(CustomerHomeProvider provider) {
    AlertModel? activeAlert;
    for (final alert in provider.recentAlerts) {
      if (!alert.isResolved) {
        activeAlert = alert;
        break;
      }
    }

    final hasIssue = !provider.serviceIsHealthy;
    final title = hasIssue
        ? 'We detected an issue'
        : 'No active issues';
    final subtitle = hasIssue
        ? (activeAlert == null
            ? 'Our team is investigating your connection.'
        : _friendlyAlertTitle(activeAlert.alertType))
        : 'Your service is stable right now.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySurfaceOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasIssue ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          if (hasIssue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySurfaceOf(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize:   16,
            fontWeight: FontWeight.bold,
            color:      AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => AppUtils.showSnackbar(
                  context,
                  'Tap the "Help" tab below for troubleshooting assistance.',
                ),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Get Help'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showReportDialog(context),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => AppUtils.showSnackbar(
                  context,
                  'Tap the "History" tab to see past issues.',
                ),
                icon: const Icon(Icons.history_rounded),
                label: const Text('History'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Recent Issues ─────────────────────────────────────────────────────────

  Widget _buildRecentIssues(CustomerHomeProvider provider) {
    final alerts = provider.recentAlerts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Issues',
          style: TextStyle(
            fontSize:   16,
            fontWeight: FontWeight.bold,
            color:      AppColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:        AppColors.primarySurfaceOf(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No recent issues. Your service has been running smoothly.',
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...alerts.map((a) => _IssueRow(alert: a)),
      ],
    );
  }

  // ── Report dialog ─────────────────────────────────────────────────────────

  void _showReportDialog(BuildContext context) {
    final TextEditingController reportController = TextEditingController();
    bool _submitting = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title:   const Text('Report an Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Describe what is happening with your connection:'),
              const SizedBox(height: 12),
              TextField(
                controller: reportController,
                maxLines:   4,
                decoration: const InputDecoration(
                  hintText: 'e.g. Internet is slow, cannot connect...',
                  border:   OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      final text = reportController.text.trim();
                      if (text.isEmpty) return;
                      setDialogState(() => _submitting = true);
                      try {
                        await ApiClient.reportIssue(text);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          AppUtils.showSnackbar(
                            context,
                            'Issue reported. A technician will follow up shortly.',
                          );
                        }
                      } catch (_) {
                        setDialogState(() => _submitting = false);
                        if (context.mounted) {
                          AppUtils.showSnackbar(
                            context,
                            'Failed to submit. Please try again.',
                            isError: true,
                          );
                        }
                      }
                    },
              child: _submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    ).whenComplete(reportController.dispose);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOnline = status == 'online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize:   12,
          fontWeight: FontWeight.bold,
          color:      AppColors.primary,
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.dividerOf(context)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final AlertModel alert;
  const _IssueRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final resolved       = alert.isResolved;
    final statusColor    = AppColors.primary;
    final badgeBg        = AppColors.primarySurfaceOf(context);
    final badgeTextColor = AppColors.primary;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.dividerOf(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            resolved ? Icons.check_circle_outline : Icons.error_outline,
            color: statusColor,
            size:  20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _friendlyAlertTitle(alert.alertType),
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      AppColors.textPrimaryOf(context),
                  ),
                ),
                Text(
                  AppUtils.timeAgo(alert.triggeredAt),
                  style: TextStyle(
                    fontSize: 11, color: AppColors.textHintOf(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        badgeBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              resolved ? 'Resolved' : 'Active',
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.bold,
                color:      badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyAlertTitle(String type) {
  switch (type) {
    case 'device_offline':  return 'Internet was offline';
    case 'high_latency':    return 'Connection was slow';
    case 'packet_loss':     return 'Packets were dropping';
    case 'high_cpu':        return 'Router was overloaded';
    case 'interface_error': return 'Network interface error';
    default:                return type.replaceAll('_', ' ');
  }
}
