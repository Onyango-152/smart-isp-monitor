import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/task_model.dart';
import 'tasks_provider.dart';

/// TaskDetailScreen shows full configuration, status, and actions
/// for a single monitoring task.
///
/// Pushed on top of the TasksScreen via MaterialPageRoute.
class TaskDetailScreen extends StatelessWidget {
  final TaskModel task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksProvider>(
      builder: (context, provider, _) {
        // Re-read the task from the provider to reflect live changes.
        final live = provider.tasks.firstWhere(
          (t) => t.id == task.id,
          orElse: () => task,
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, live),
              SliverToBoxAdapter(child: _buildStatusCard(context, live)),
              SliverToBoxAdapter(child: _buildStatsRow(live)),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title:    'Task Configuration',
                  subtitle: 'Monitoring parameters',
                  icon:     Icons.tune_rounded,
                ),
              ),
              SliverToBoxAdapter(child: _buildConfigInfo(context, live)),
              if (live.description != null &&
                  live.description!.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title:    'Description',
                    subtitle: 'Task purpose',
                    icon:     Icons.description_rounded,
                  ),
                ),
                SliverToBoxAdapter(child: _buildDescription(context, live)),
              ],
              SliverToBoxAdapter(
                child: SectionHeader(
                  title:    'Actions',
                  subtitle: 'Task controls',
                  icon:     Icons.flash_on_rounded,
                ),
              ),
              SliverToBoxAdapter(
                  child: _buildActions(context, provider, live)),
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        );
      },
    );
  }

  // ── Sliver App Bar ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context, TaskModel t) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned:    true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) {
            if (value == 'edit') {
              _openEdit(context, t);
            } else if (value == 'delete') {
              _showDeleteDialog(context, t);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit',   child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [
                AppColors.appBarGradientStart,
                AppColors.appBarGradientEnd,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Type icon
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      TasksProvider.taskTypeIcon(t.taskType),
                      size:  30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize:   20,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          TasksProvider.taskTypeLabel(t.taskType),
                          style: const TextStyle(
                            color:    Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: TasksProvider.statusColor(t.lastStatus)
                                    .withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t.lastStatus[0].toUpperCase() +
                                    t.lastStatus.substring(1),
                                style: TextStyle(
                                  color: t.lastStatus == 'success'
                                      ? Colors.greenAccent
                                      : t.lastStatus == 'failed'
                                          ? Colors.redAccent
                                          : Colors.amberAccent,
                                  fontSize:   11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Enabled / disabled badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: t.enabled
                                    ? Colors.green.withOpacity(0.25)
                                    : Colors.red.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t.enabled ? 'Enabled' : 'Disabled',
                                style: TextStyle(
                                  color: t.enabled
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontSize:   11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          t.name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        titlePadding: const EdgeInsets.only(left: 50, bottom: 14),
      ),
    );
  }

  // ── Status Card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard(BuildContext context, TaskModel t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    AppShadows.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: _InfoPill(
                icon:  Icons.circle,
                label: 'Status',
                value: t.lastStatus[0].toUpperCase() +
                    t.lastStatus.substring(1),
                color: TasksProvider.statusColor(t.lastStatus),
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.dividerOf(context)),
            Expanded(
              child: _InfoPill(
                icon:  Icons.schedule_rounded,
                label: 'Last Run',
                value: t.lastRun != null
                    ? AppUtils.timeAgo(t.lastRun)
                    : 'Never',
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.dividerOf(context)),
            Expanded(
              child: _InfoPill(
                icon:  Icons.timer_outlined,
                label: 'Interval',
                value: TasksProvider.formatInterval(t.intervalSecs),
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(TaskModel t) {
    final typeColor = _typeColor(t.taskType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _StatCard(
            label: 'Type',
            value: t.taskType.toUpperCase(),
            icon:  TasksProvider.taskTypeIcon(t.taskType),
            color: typeColor,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Timeout',
            value: '${t.timeoutSecs}s',
            icon:  Icons.hourglass_bottom_rounded,
            color: AppColors.degraded,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Device',
            value: t.deviceName != null ? '1' : 'All',
            icon:  Icons.router_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'State',
            value: t.enabled ? 'On' : 'Off',
            icon:  t.enabled
                ? Icons.check_circle_rounded
                : Icons.pause_circle_rounded,
            color: t.enabled ? AppColors.online : AppColors.offline,
          ),
        ],
      ),
    );
  }

  // ── Configuration Info ────────────────────────────────────────────────────

  Widget _buildConfigInfo(BuildContext context, TaskModel t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow:    AppShadows.card,
        ),
        child: Column(
          children: [
            InfoRow(
              label: 'Task Name',
              value: t.name,
              icon:  Icons.label_rounded,
              copyable: true,
            ),
            InfoRow(
              label: 'Task Type',
              value: TasksProvider.taskTypeLabel(t.taskType),
              icon:  TasksProvider.taskTypeIcon(t.taskType),
              valueColor: _typeColor(t.taskType),
            ),
            InfoRow(
              label: 'Target Device',
              value: t.deviceName ?? 'All Devices',
              icon:  Icons.router_rounded,
            ),
            InfoRow(
              label: 'Polling Interval',
              value: TasksProvider.formatInterval(t.intervalSecs),
              icon:  Icons.repeat_rounded,
            ),
            InfoRow(
              label: 'Timeout',
              value: '${t.timeoutSecs} seconds',
              icon:  Icons.hourglass_bottom_rounded,
            ),
            InfoRow(
              label: 'Created',
              value: AppUtils.formatDateTime(t.createdAt),
              icon:  Icons.calendar_today_rounded,
            ),
            InfoRow(
              label:  'Last Updated',
              value:  t.updatedAt != null
                  ? AppUtils.formatDateTime(t.updatedAt)
                  : '—',
              icon:   Icons.update_rounded,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────

  Widget _buildDescription(BuildContext context, TaskModel t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow:    AppShadows.card,
        ),
        child: Text(
          t.description!,
          style: AppTextStyles.body,
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Widget _buildActions(
      BuildContext context, TasksProvider provider, TaskModel t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Toggle enable / disable
          _ActionTile(
            icon:  t.enabled
                ? Icons.pause_circle_rounded
                : Icons.play_circle_rounded,
            label: t.enabled ? 'Disable Task' : 'Enable Task',
            subtitle: t.enabled
                ? 'Pause this monitoring task'
                : 'Resume this monitoring task',
            color: t.enabled ? AppColors.offline : AppColors.online,
            onTap: () {
              AppUtils.hapticSelect();
              provider.toggleEnabled(t.id);
              AppUtils.showSnackbar(
                context,
                t.enabled
                    ? '${t.name} disabled'
                    : '${t.name} enabled',
              );
            },
          ),
          const SizedBox(height: 8),
          // Run now
          _ActionTile(
            icon:     Icons.play_arrow_rounded,
            label:    'Run Now',
            subtitle: 'Execute this task immediately',
            color:    AppColors.primary,
            enabled:  t.enabled,
            onTap: () {
              AppUtils.hapticSelect();
              provider.runNow(t.id);
              AppUtils.showSnackbar(context, '${t.name} executed');
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // ── Edit / Delete helpers ──────────────────────────────────────────────

  void _openEdit(BuildContext context, TaskModel t) async {
    final updated = await Navigator.of(context)
        .pushNamed(AppConstants.taskFormRoute, arguments: t);
    if (updated == true && context.mounted) {
      AppUtils.showSnackbar(context, 'Task updated');
    }
  }

  void _showDeleteDialog(BuildContext context, TaskModel t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Delete Task'),
        content: Text('Delete "${t.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // close dialog
              final provider = context.read<TasksProvider>();
              final ok = await provider.deleteTask(t.id);
              if (context.mounted) {
                Navigator.of(context).pop(); // pop detail screen
                if (ok) {
                  AppUtils.showSnackbar(context, 'Task deleted');
                } else {
                  AppUtils.showSnackbar(context, 'Delete failed',
                      isError: true);
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.offline)),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'snmp': return AppColors.primary;
      case 'ping': return AppColors.online;
      case 'http': return AppColors.degraded;
      case 'tcp':  return AppColors.maintenance;
      case 'dns':  return const Color(0xFF0891B2);
      default:     return AppColors.unknown;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoPill — compact icon + label + value
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.labelBold.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCard — small KPI card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow:    AppShadows.small,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.heading2.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionTile — tappable action row
// ─────────────────────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final String       subtitle;
  final Color        color;
  final bool         enabled;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow:    AppShadows.card,
            border: Border.all(
              color: enabled ? color.withOpacity(0.3) : AppColors.dividerOf(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: (enabled ? color : AppColors.textHintOf(context))
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22,
                    color: enabled ? color : AppColors.textHintOf(context)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.heading3.copyWith(
                        color: enabled ? null : AppColors.textHintOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enabled ? subtitle : 'Enable the task first',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20,
                  color: enabled ? color : AppColors.textHintOf(context)),
            ],
          ),
        ),
      ),
    );
  }
}
