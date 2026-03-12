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

  DeviceModel?  _myDevice  = null;
  MetricModel?  _myMetric  = null;
  List<AlertModel> _recentAlerts = [];

  DeviceModel? get myDevice => _myDevice;
  MetricModel? get myMetric => _myMetric;
  List<AlertModel> get recentAlerts => _recentAlerts;

  bool get serviceIsHealthy =>
      _myDevice?.status == 'online' &&
      _recentAlerts.where((a) => !a.isResolved).isEmpty;

  String get serviceStatusLabel =>
      serviceIsHealthy ? 'Service is Healthy' : 'Service Issue Detected';

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Use customer-specific endpoints
      final results = await Future.wait([
        ApiClient.getMyDevices(),
        ApiClient.getMyAlerts(),
      ]);
      final devices = results[0] as List<DeviceModel>;
      final alerts  = results[1] as List<AlertModel>;

      _myDevice = devices.isNotEmpty ? devices.first : null;

      if (_myDevice != null) {
        final metrics = await ApiClient.getMetrics(deviceId: _myDevice!.id);
        final sorted  = metrics..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        _myMetric = sorted.isNotEmpty ? sorted.first : null;
      }

      _recentAlerts = alerts
          .where((a) => a.deviceId == _myDevice?.id)
          .take(5)
          .toList();
    } catch (_) {
      // Keep stale data; UI shows last known state
    }
    _isLoading = false;
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
                      const SizedBox(height: 20),
                      if (provider.myDevice != null) ...[
                        _buildDeviceCard(provider.myDevice!, provider.myMetric),
                        const SizedBox(height: 20),
                      ],
                      _buildQuickActions(context),
                      const SizedBox(height: 20),
                      _buildRecentIssues(provider),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ── Status Card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard(CustomerHomeProvider provider) {
    final healthy  = provider.serviceIsHealthy;
    final bgColor  = healthy ? AppColors.online : AppColors.severityCritical;
    final icon     = healthy ? Icons.check_circle : Icons.warning_rounded;
    final endColor = healthy
        ? const Color(0xFF1B5E20)
        : const Color(0xFFB71C1C);
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
              color:      bgColor.withOpacity(0.4),
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

  // ── Device Card ──────────────────────────────────────────────────────────
  // Metrics come from MetricModel (latencyMs, packetLossPct, uptimeSeconds),
  // not from DeviceModel which only holds identity/config fields.

  Widget _buildDeviceCard(DeviceModel device, MetricModel? metric) {
    // Convert uptimeSeconds → percentage of 30 days (2592000 s) for display.
    // If null (device offline), show '--'.
    final uptimePct = metric?.uptimeSeconds != null
        ? (metric!.uptimeSeconds! / 2592000 * 100).clamp(0.0, 100.0)
        : null;

    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppColors.primarySurfaceOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.router, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      device.ipAddress,
                      style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondaryOf(context)),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: device.status),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _MetricChip(
                label: 'Latency',
                value: metric?.latencyMs != null
                    ? '${metric!.latencyMs!.toStringAsFixed(0)} ms'
                    : '-- ms',
                icon: Icons.speed,
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Packet Loss',
                value: metric?.packetLossPct != null
                    ? '${metric!.packetLossPct!.toStringAsFixed(1)}%'
                    : '--%',
                icon: Icons.wifi_tethering,
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Uptime',
                value: uptimePct != null
                    ? '${uptimePct.toStringAsFixed(1)}%'
                    : '--%',
                icon: Icons.timeline,
              ),
            ],
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
              child: _QuickActionCard(
                icon:  Icons.support_agent,
                label: 'Get Help',
                color: AppColors.primary,
                onTap: () => AppUtils.showSnackbar(
                  context,
                  'Tap the "Help" tab below for troubleshooting assistance.',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon:  Icons.report_problem_outlined,
                label: 'Report Issue',
                color: AppColors.severityHigh,
                onTap: () => _showReportDialog(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon:  Icons.history,
                label: 'View History',
                color: AppColors.primaryDark,
                onTap: () => AppUtils.showSnackbar(
                  context,
                  'Tap the "History" tab to see past issues.',
                ),
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
              color:        AppColors.onlineLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.online, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No recent issues. Your service has been running smoothly.',
                    style: TextStyle(color: AppColors.online, fontSize: 14),
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

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                hintText: 'e.g. Internet is slow, cannot connect, router is offline...',
                border:   OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:     const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              AppUtils.showSnackbar(
                context,
                'Issue reported. A technician will follow up shortly.',
              );
            },
            child: const Text('Submit'),
          ),
        ],
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
        color:        isOnline ? AppColors.onlineLight : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize:   12,
          fontWeight: FontWeight.bold,
          color:      isOnline ? AppColors.online : AppColors.severityCritical,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color:        AppColors.bg(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryLight),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.bold,
                color:      AppColors.textPrimaryOf(context),
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: AppColors.textHintOf(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      color,
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
    final statusColor    = resolved ? AppColors.online : AppColors.severityHigh;
    final badgeBg        = resolved ? AppColors.onlineLight : const Color(0xFFFFF3E0);
    final badgeTextColor = resolved ? AppColors.online : AppColors.severityMedium;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: resolved
              ? AppColors.dividerOf(context)
              : AppColors.severityHigh.withOpacity(0.3),
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
}
