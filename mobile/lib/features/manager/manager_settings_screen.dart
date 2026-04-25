import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/organisation_model.dart';
import '../../services/api_client.dart';
import '../auth/auth_provider.dart';
import '../alerts/alerts_provider.dart';
import '../tasks/tasks_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ManagerSettingsProvider
// ─────────────────────────────────────────────────────────────────────────────

class ManagerSettingsProvider extends ChangeNotifier {
  // Notification preferences
  bool _alertsCritical    = true;
  bool _alertsAllSeverity = false;
  bool _dailySummary      = true;
  bool _weeklyReport      = true;

  // SLA targets
  double _slaUptimeTarget = 99.0;   // percentage
  int    _slaRespMinutes  = 15;     // minutes to first response
  int    _mttrTargetHours = 4;      // hours
  int    _autoEscalateH   = 24;     // hours before auto-escalate

  bool   get alertsCritical    => _alertsCritical;
  bool   get alertsAllSeverity => _alertsAllSeverity;
  bool   get dailySummary      => _dailySummary;
  bool   get weeklyReport      => _weeklyReport;
  double get slaUptimeTarget   => _slaUptimeTarget;
  int    get slaRespMinutes    => _slaRespMinutes;
  int    get mttrTargetHours   => _mttrTargetHours;
  int    get autoEscalateH     => _autoEscalateH;

  void toggle(String key) {
    switch (key) {
      case 'alertsCritical':    _alertsCritical    = !_alertsCritical;    break;
      case 'alertsAllSeverity': _alertsAllSeverity = !_alertsAllSeverity; break;
      case 'dailySummary':      _dailySummary      = !_dailySummary;      break;
      case 'weeklyReport':      _weeklyReport      = !_weeklyReport;      break;
    }
    notifyListeners();
  }

  void setSlaUptime(double v)        { _slaUptimeTarget = v; notifyListeners(); }
  void setSlaRespMinutes(int v)      { _slaRespMinutes  = v; notifyListeners(); }
  void setMttrTarget(int v)         { _mttrTargetHours = v; notifyListeners(); }
  void setAutoEscalate(int v)       { _autoEscalateH   = v; notifyListeners(); }
}

// ─────────────────────────────────────────────────────────────────────────────
// ManagerSettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class ManagerSettingsScreen extends StatelessWidget {
  const ManagerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ManagerSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()..loadAlerts()),
        ChangeNotifierProvider(create: (_) => TasksProvider()..loadTasks()),
      ],
      child: const _ManagerSettingsContent(),
    );
  }
}

class _ManagerSettingsContent extends StatelessWidget {
  const _ManagerSettingsContent();

  @override
  Widget build(BuildContext context) {
    final auth     = context.read<AuthProvider>();
    final settings = context.watch<ManagerSettingsProvider>();
    final user     = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [AppColors.appBarGradientStart, AppColors.appBarGradientEnd],
            ),
          ),
        ),
        title: const Text(
          'Manager Settings',
          style: TextStyle(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // ── Hero ───────────────────────────────────────────────────────
          _buildHero(context, user),

          const SizedBox(height: 28),

          // ── Business Operations ────────────────────────────────────────
          _buildCard('Business Operations', [
            _Tile(
              icon: Icons.group_rounded,
              iconColor: AppColors.primary,
              title: 'Team Management',
              subtitle: 'Invite & manage org members',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => _openTeamManagement(context),
            ),
            _Tile(
              icon: Icons.credit_card_rounded,
              iconColor: AppColors.primaryDark,
              title: 'Billing System',
              subtitle: 'Open Centrika ISP billing portal',
              trailing: const Icon(Icons.open_in_new_rounded,
                  size: 18, color: AppColors.textSecondary),
              onTap: () => _openBillingSystem(context),
            ),
            _Tile(
              icon: Icons.summarize_rounded,
              iconColor: AppColors.primary,
              title: 'Generate Monthly Report',
              subtitle: 'Export a full network & SLA report',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              isLast: true,
              onTap: () => _generateReport(context),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Technician Oversight ───────────────────────────────────────
          _buildCard('Technician Oversight', [
            _Tile(
              icon: Icons.engineering_rounded,
              iconColor: AppColors.primary,
              title: 'Technician Performance',
              subtitle: 'Task completion, response times, open issues',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => _showTechnicianPerformance(context),
            ),
            _Tile(
              icon: Icons.assignment_late_rounded,
              iconColor: AppColors.primaryDark,
              title: 'Unassigned Tasks',
              subtitle: 'Tasks not yet assigned to a technician',
              trailing: _UnassignedTasksBadge(),
              onTap: () => _showUnassignedTasks(context),
            ),
            _Tile(
              icon: Icons.alarm_rounded,
              iconColor: AppColors.primaryLight,
              title: 'Auto-Escalate After',
              subtitle: 'Escalate unresolved issues after ${settings.autoEscalateH}h',
              isLast: true,
              trailing: _PickerChip(
                value: '${settings.autoEscalateH}h',
                onTap: () => _pickHours(
                  context: context,
                  label: 'Auto-Escalate Threshold',
                  current: settings.autoEscalateH,
                  options: [4, 8, 12, 24, 48, 72],
                  onSelected: settings.setAutoEscalate,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Customer Issues ────────────────────────────────────────────
          _buildCard('Customer Issues', [
            _Tile(
              icon: Icons.support_agent_rounded,
              iconColor: AppColors.primaryDark,
              title: 'Open Customer Alerts',
              subtitle: 'Active alerts affecting customer devices',
              trailing: _OpenAlertsBadge(),
              onTap: () => _showOpenCustomerAlerts(context),
            ),
            _Tile(
              icon: Icons.verified_rounded,
              iconColor: AppColors.primary,
              title: 'SLA Compliance',
              subtitle: 'Uptime & response time against SLA targets',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => _showSlaCompliance(context, settings),
            ),
            _Tile(
              icon: Icons.speed_rounded,
              iconColor: AppColors.primaryDark,
              title: 'First Response Target',
              subtitle: '${settings.slaRespMinutes} min — time before first acknowledgement',
              isLast: true,
              trailing: _PickerChip(
                value: '${settings.slaRespMinutes}m',
                onTap: () => _pickMinutes(
                  context: context,
                  label: 'Response Time Target',
                  current: settings.slaRespMinutes,
                  options: [5, 10, 15, 30, 60],
                  onSelected: settings.setSlaRespMinutes,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Network SLA Targets ────────────────────────────────────────
          _buildCard('Network SLA Targets', [
            _Tile(
              icon: Icons.bar_chart_rounded,
              iconColor: AppColors.primary,
              title: 'Uptime SLA Target',
              subtitle: '${settings.slaUptimeTarget.toStringAsFixed(1)}% required uptime',
              trailing: _PickerChip(
                value: '${settings.slaUptimeTarget.toStringAsFixed(1)}%',
                onTap: () => _pickUptime(context, settings),
              ),
            ),
            _Tile(
              icon: Icons.timer_rounded,
              iconColor: AppColors.primaryLight,
              title: 'MTTR Target',
              subtitle: 'Mean time to resolution: ${settings.mttrTargetHours}h',
              isLast: true,
              trailing: _PickerChip(
                value: '${settings.mttrTargetHours}h',
                onTap: () => _pickHours(
                  context: context,
                  label: 'MTTR Target',
                  current: settings.mttrTargetHours,
                  options: [1, 2, 4, 8, 12, 24],
                  onSelected: settings.setMttrTarget,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Notifications ──────────────────────────────────────────────
          _buildCard('Notifications', [
            _Tile(
              icon: Icons.crisis_alert_rounded,
              iconColor: AppColors.primaryDark,
              title: 'Critical Alerts',
              subtitle: 'Immediate push for severity=critical',
              trailing: Switch(
                value: settings.alertsCritical,
                onChanged: (_) => settings.toggle('alertsCritical'),
                activeColor: AppColors.primary,
              ),
            ),
            _Tile(
              icon: Icons.notifications_active_rounded,
              iconColor: AppColors.primaryLight,
              title: 'All Severity Alerts',
              subtitle: 'Notify for medium and low severity too',
              trailing: Switch(
                value: settings.alertsAllSeverity,
                onChanged: (_) => settings.toggle('alertsAllSeverity'),
                activeColor: AppColors.primary,
              ),
            ),
            _Tile(
              icon: Icons.today_rounded,
              iconColor: AppColors.primaryDark,
              title: 'Daily Summary',
              subtitle: 'Morning briefing: overnight faults & status',
              trailing: Switch(
                value: settings.dailySummary,
                onChanged: (_) => settings.toggle('dailySummary'),
                activeColor: AppColors.primary,
              ),
            ),
            _Tile(
              icon: Icons.calendar_today_rounded,
              iconColor: AppColors.primaryLight,
              title: 'Weekly Performance Report',
              subtitle: 'Friday summary: uptime, MTTR, SLA compliance',
              isLast: true,
              trailing: Switch(
                value: settings.weeklyReport,
                onChanged: (_) => settings.toggle('weeklyReport'),
                activeColor: AppColors.primary,
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── System ─────────────────────────────────────────────────────
          _buildCard('System', [
            _Tile(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: 'About Smart ISP Monitor',
              subtitle: 'Version 1.0.0 — build 1',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Smart ISP Monitor',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Smart ISP',
              ),
            ),
            _Tile(
              icon: Icons.logout_rounded,
              iconColor: AppColors.offline,
              title: 'Sign Out',
              subtitle: 'Log out of the manager portal',
              isLast: true,
              onTap: () => _confirmSignOut(context),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Hero (cardless, centered) ─────────────────────────────────────────────

  Widget _buildHero(BuildContext context, dynamic user) {
    final name    = user?.username ?? 'Manager';
    final email   = user?.email    ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primarySurface,
            child: Text(
              initial,
              style: const TextStyle(
                color:      AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize:   32,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            name,
            style: const TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          if (email.isNotEmpty)
            Text(
              email,
              style: const TextStyle(
                fontSize: 13,
                color:    AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color:        AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Manager',
              style: TextStyle(
                color:      AppColors.primary,
                fontSize:   12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _openTeamManagement(BuildContext context) async {
    // Load orgs, then navigate — if only one org go straight in
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final orgs = await ApiClient.getMyOrganisations();
      if (!context.mounted) return;
      Navigator.pop(context); // close loader

      if (orgs.isEmpty) {
        AppUtils.showSnackbar(
            context, 'No organisations found. Create one first.',
            isError: true);
        return;
      }
      if (orgs.length == 1) {
        Navigator.pushNamed(
          context,
          AppConstants.orgMembersRoute,
          arguments: {'orgId': orgs.first.id, 'orgName': orgs.first.name},
        );
        return;
      }
      // Multiple orgs — show picker
      _showOrgPicker(context, orgs);
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context);
        AppUtils.showSnackbar(context, 'Failed to load organisations.',
            isError: true);
      }
    }
  }

  void _showOrgPicker(BuildContext context, List<OrganisationModel> orgs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Organisation', style: AppTextStyles.heading1),
            const SizedBox(height: 12),
            ...orgs.map((org) => ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Icon(Icons.business_rounded, color: AppColors.primary),
              ),
              title: Text(org.name, style: AppTextStyles.heading3),
              subtitle: Text('${org.membersCount} members',
                  style: AppTextStyles.caption),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  AppConstants.orgMembersRoute,
                  arguments: {'orgId': org.id, 'orgName': org.name},
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  void _openBillingSystem(BuildContext context) {
    const billingUrl = 'https://centrika.net';
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.credit_card_rounded, color: AppColors.primaryDark),
            SizedBox(width: 8),
            Text('Billing System'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Open the Centrika ISP billing portal in your browser:',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(billingUrl,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: billingUrl));
              Navigator.pop(context);
              AppUtils.showSnackbar(context, 'URL copied to clipboard');
            },
            icon:  const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Link'),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }

  void _generateReport(BuildContext context) {
    AppUtils.showSnackbar(context,
        'Report generation — backend export endpoint coming soon');
  }


  void _showTechnicianPerformance(BuildContext context) {
    final tasks = context.read<TasksProvider>().tasks;
    _showPerformanceSheet(context, tasks);
  }

  void _showUnassignedTasks(BuildContext context) {
    final unassigned = context.read<TasksProvider>()
        .tasks
        .where((t) => t.enabled && t.lastStatus == 'pending')
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _UnassignedTasksSheet(tasks: unassigned),
    );
  }

  void _showOpenCustomerAlerts(BuildContext context) {
    final active = context.read<AlertsProvider>()
        .activeAlerts
        .take(20)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _CustomerAlertsSheet(alerts: active),
    );
  }

  void _showSlaCompliance(
      BuildContext context, ManagerSettingsProvider settings) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('SLA Compliance'),
        content: _SlaComplianceContent(settings: settings),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _pickUptime(BuildContext context, ManagerSettingsProvider s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uptime SLA Target'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${s.slaUptimeTarget.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              Slider(
                value:    s.slaUptimeTarget,
                min:      90,
                max:      100,
                divisions: 20,
                label:    '${s.slaUptimeTarget.toStringAsFixed(1)}%',
                onChanged: (v) {
                  setState(() => s.setSlaUptime(v));
                },
                activeColor: AppColors.primary,
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('90%', style: TextStyle(fontSize: 11)),
                  Text('99.9%', style: TextStyle(fontSize: 11)),
                  Text('100%', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done')),
        ],
      ),
    );
  }

  void _pickHours({
    required BuildContext context,
    required String label,
    required int current,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(label),
        children: options
            .map((h) => RadioListTile<int>(
                  title: Text('$h hour${h == 1 ? '' : 's'}'),
                  value: h,
                  groupValue: current,
                  onChanged: (v) {
                    if (v != null) {
                      onSelected(v);
                      Navigator.pop(context);
                    }
                  },
                  activeColor: AppColors.primary,
                ))
            .toList(),
      ),
    );
  }

  void _pickMinutes({
    required BuildContext context,
    required String label,
    required int current,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(label),
        children: options
            .map((m) => RadioListTile<int>(
                  title: Text('$m minute${m == 1 ? '' : 's'}'),
                  value: m,
                  groupValue: current,
                  onChanged: (v) {
                    if (v != null) {
                      onSelected(v);
                      Navigator.pop(context);
                    }
                  },
                  activeColor: AppColors.primary,
                ))
            .toList(),
      ),
    );
  }


  void _confirmSignOut(BuildContext context) {
    final parentContext = context;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await parentContext.read<AuthProvider>().logout();
              } catch (_) {
                // Fall through to navigation even if logout cleanup fails.
              }
              if (!parentContext.mounted) return;
              Navigator.of(parentContext, rootNavigator: true)
                  .pushNamedAndRemoveUntil(
                AppConstants.loginRoute,
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryDark),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  // ── Performance sheet helper ──────────────────────────────────────────────

  void _showPerformanceSheet(
      BuildContext context, List<TaskModel> tasks) {
    final enabled   = tasks.where((t) => t.enabled).toList();
    final failed    = enabled.where((t) => t.lastStatus == 'failed').length;
    final succeeded = enabled.where((t) => t.lastStatus == 'success').length;
    final pending   = enabled.where((t) => t.lastStatus == 'pending').length;
    final total     = enabled.length;
    final rate      = total > 0 ? succeeded / total * 100 : 0.0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.engineering_rounded,
                    color: AppColors.primaryDark),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Technician Performance',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(_)),
              ],
            ),
            const Divider(height: 20),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatBox(label: 'Tasks', value: '$total',
                    color: AppColors.primaryDark),
                _StatBox(label: 'Success', value: '$succeeded',
                  color: AppColors.primary),
                _StatBox(label: 'Failed', value: '$failed',
                  color: AppColors.primaryDark),
                _StatBox(label: 'Pending', value: '$pending',
                  color: AppColors.primaryLight),
              ],
            ),
            const SizedBox(height: 16),
            // Completion rate bar
            Row(
              children: [
                const Text('Completion Rate',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${rate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:           rate / 100,
                minHeight:       10,
                backgroundColor: AppColors.divider,
                color: rate >= 80
                  ? AppColors.primary
                  : rate >= 50
                    ? AppColors.primaryLight
                    : AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            if (failed > 0)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color:        AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(
                      color: AppColors.primaryDark.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                      color: AppColors.primaryDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$failed task${failed == 1 ? '' : 's'} currently failing — review and reassign.',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Shared card builder ───────────────────────────────────────────────────

  static Widget _buildCard(String title, List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category title inside the card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Divider(height: 8),
            ...tiles,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet widgets
// ─────────────────────────────────────────────────────────────────────────────

class _UnassignedTasksSheet extends StatelessWidget {
  final List<TaskModel> tasks;
  const _UnassignedTasksSheet({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: Column(
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                    const Icon(Icons.assignment_late_rounded,
                      color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Text('Unassigned Tasks (${tasks.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                      child: Text('All tasks are assigned ✓',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: ctrl,
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final t = tasks[i];
                        return ListTile(
                            leading: const Icon(Icons.task_alt_rounded,
                              color: AppColors.primaryLight),
                          title: Text(t.name),
                          subtitle: Text(t.deviceName ?? '—'),
                          trailing: Text(t.taskType,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerAlertsSheet extends StatelessWidget {
  final List<AlertModel> alerts;
  const _CustomerAlertsSheet({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: Column(
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded,
                      color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Text('Open Alerts (${alerts.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: alerts.isEmpty
                  ? const Center(
                      child: Text('No open alerts ✓',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: ctrl,
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final a = alerts[i];
                        final color = a.severity == 'critical'
                          ? AppColors.primaryDark
                            : a.severity == 'high'
                            ? AppColors.primary
                            : AppColors.primaryLight;
                        return ListTile(
                          leading: Icon(Icons.warning_amber_rounded,
                              color: color),
                          title: Text(a.alertType),
                          subtitle: Text(a.deviceName),
                          trailing: Text(
                            AppUtils.timeAgo(a.triggeredAt),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlaComplianceContent extends StatelessWidget {
  final ManagerSettingsProvider settings;
  const _SlaComplianceContent({required this.settings});

  @override
  Widget build(BuildContext context) {
    // Derive from live dashboard data if available
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SlaRow(
          label: 'Uptime Target',
          target: '${settings.slaUptimeTarget.toStringAsFixed(1)}%',
          status: 'Tracking from dashboard metrics',
        ),
        const Divider(height: 20),
        _SlaRow(
          label: 'First Response',
          target: '${settings.slaRespMinutes} min',
          status: 'Measured from alert creation to acknowledgement',
        ),
        const Divider(height: 20),
        _SlaRow(
          label: 'MTTR Target',
          target: '${settings.mttrTargetHours}h',
          status: 'Mean time from alert to resolved',
        ),
      ],
    );
  }
}

class _SlaRow extends StatelessWidget {
  final String label;
  final String target;
  final String status;
  const _SlaRow(
      {required this.label, required this.target, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(status,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(target,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge widgets (read live data from providers in the tree)
// ─────────────────────────────────────────────────────────────────────────────

class _OpenAlertsBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<AlertsProvider>().activeAlerts.length;
    if (count == 0) {
      return const Icon(Icons.check_circle_rounded,
          color: AppColors.primary, size: 20);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        AppColors.primaryDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _UnassignedTasksBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context
        .watch<TasksProvider>()
        .tasks
        .where((t) => t.enabled && t.lastStatus == 'pending')
        .length;
    if (count == 0) {
      return const Icon(Icons.check_circle_rounded,
          color: AppColors.primary, size: 20);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable UI pieces
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // replaced by in-card headers
  }
}

class _Tile extends StatelessWidget {
  final IconData  icon;
  final Color     iconColor;
  final String    title;
  final String    subtitle;
  final Widget?   trailing;
  final VoidCallback? onTap;
  final bool      isLast;

  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final topRadius    = BorderRadius.zero;
    final bottomRadius = isLast
        ? const BorderRadius.vertical(bottom: Radius.circular(14))
        : BorderRadius.zero;
    final radius = BorderRadius.only(
      bottomLeft:  bottomRadius.bottomLeft,
      bottomRight: bottomRadius.bottomRight,
    );

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 68, endIndent: 0),
      ],
    );
  }
}

class _PickerChip extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _PickerChip({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(
              color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        child: Text(value,
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 4,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color:        AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
