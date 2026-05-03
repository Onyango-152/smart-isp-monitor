import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/task_model.dart';
import '../alerts/alerts_provider.dart';
import '../auth/auth_provider.dart';
import 'tasks_provider.dart';
import 'task_detail_screen.dart';

/// TasksScreen shows all scheduled monitoring tasks in two tabs:
/// Enabled (active) and Disabled.
///
/// Features:
///   - Gradient AppBar with total task count badge
///   - TabBar: Enabled | Disabled (with count badges)
///   - Search bar + task-type filter chips
///   - Pull-to-refresh on both tabs
///   - Task cards with status indicator, type icon, interval, device
///   - Quick toggle enabled/disabled via switch
///   - Run Now button on enabled tasks
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final provider = context.read<TasksProvider>();
    if (provider.searchQuery.isNotEmpty) {
      _searchController.text = provider.searchQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.loadTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksProvider>(
      builder: (context, provider, _) {
        final auth = context.read<AuthProvider>();
        AlertsProvider? alertsProvider;
        try {
          alertsProvider = Provider.of<AlertsProvider>(context, listen: false);
        } catch (_) {
          alertsProvider = null;
        }
        final showReports = auth.isTechnician && alertsProvider != null;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar:          _buildAppBar(provider),
          body:            _buildBody(
            provider,
            showReports: showReports,
            alertsProvider: alertsProvider,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final created = await Navigator.of(context)
                  .pushNamed(AppConstants.taskFormRoute);
              if (created == true && mounted) {
                AppUtils.showSnackbar(context, 'Task created');
              }
            },
            backgroundColor: AppColors.primary,
            icon:  const Icon(Icons.add_rounded, color: AppColors.textOnDark),
            label: const Text('New Task',
              style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    TasksProvider provider, {
    required bool showReports,
    AlertsProvider? alertsProvider,
  }) {
    if (provider.isLoading) {
      return ShimmerSkeleton.deviceList();
    }

    if (provider.hasError) {
      return EmptyState(
        icon:        Icons.cloud_off_rounded,
        title:       'Could Not Load Tasks',
        message:     provider.errorMessage!,
        color:       AppColors.primaryDark,
        actionLabel: 'Retry',
        onAction:    provider.loadTasks,
      );
    }

    return Column(
      children: [
        if (showReports && alertsProvider != null) ...[
          _buildCustomerReportsSection(alertsProvider),
          const SizedBox(height: 6),
        ],
        _buildSearchBar(provider),
        if (provider.hasActiveFilters) _buildResultsBar(provider),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList(
                provider: provider,
                tasks:    provider.enabledTasks,
                isEnabled: true,
              ),
              _buildTaskList(
                provider: provider,
                tasks:    provider.disabledTasks,
                isEnabled: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(TasksProvider provider) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: Container(
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
      ),
      title: Row(
        children: [
          const Text('Tasks', style: TextStyle(color: Colors.white)),
          if (!provider.isLoading && !provider.hasError) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.totalCount}',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: provider.isLoading ? null : () {
            AppUtils.haptic();
            provider.refresh();
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: _buildTabBar(provider),
    );
  }

  PreferredSizeWidget _buildTabBar(TasksProvider provider) {
    return TabBar(
      controller:           _tabController,
      labelColor:           Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor:       Colors.white,
      indicatorWeight:      3,
      tabs: [
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Enabled'),
              if (provider.failedCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color:        AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${provider.failedCount}',
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ] else if (provider.enabledCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${provider.enabledCount}',
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Disabled'),
              if (provider.disabledCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${provider.disabledCount}',
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(TasksProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller:  _searchController,
        onChanged:   provider.search,
        style:       AppTextStyles.body,
        decoration: InputDecoration(
          hintText:   'Search by name, device, type…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: provider.searchQuery.isNotEmpty
              ? IconButton(
                  icon:      const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    provider.search('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ── Filter chip row ───────────────────────────────────────────────────────

  Widget _buildFilterRow(TasksProvider provider) {
    return SizedBox(
      height: 46,
      child: ListView(
        padding:         const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        children: [
          // ── Type chips ────────────────────────────────────────────────
          _FilterChip(
            label:    'All Types',
            selected: provider.typeFilter == 'all',
            onTap:    () => provider.setTypeFilter('all'),
          ),
          _FilterChip(
            label:    'SNMP',
            selected: provider.typeFilter == 'snmp',
            onTap:    () => provider.setTypeFilter('snmp'),
            color:    AppColors.primary,
          ),
          _FilterChip(
            label:    'Ping',
            selected: provider.typeFilter == 'ping',
            onTap:    () => provider.setTypeFilter('ping'),
            color:    AppColors.primaryLight,
          ),
          _FilterChip(
            label:    'HTTP',
            selected: provider.typeFilter == 'http',
            onTap:    () => provider.setTypeFilter('http'),
            color:    AppColors.primaryDark,
          ),
          _FilterChip(
            label:    'TCP',
            selected: provider.typeFilter == 'tcp',
            onTap:    () => provider.setTypeFilter('tcp'),
            color:    AppColors.primaryDark,
          ),
          _FilterChip(
            label:    'DNS',
            selected: provider.typeFilter == 'dns',
            onTap:    () => provider.setTypeFilter('dns'),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child:   VerticalDivider(width: 1),
          ),

          // ── Status chips ──────────────────────────────────────────────
          _FilterChip(
            label:    'Success',
            selected: provider.statusFilter == 'success',
            onTap:    () => provider.setStatusFilter(
                provider.statusFilter == 'success' ? 'all' : 'success'),
            color:    AppColors.primary,
          ),
          _FilterChip(
            label:    'Failed',
            selected: provider.statusFilter == 'failed',
            onTap:    () => provider.setStatusFilter(
                provider.statusFilter == 'failed' ? 'all' : 'failed'),
            color:    AppColors.primaryDark,
          ),
        ],
      ),
    );
  }

  // ── Results bar ───────────────────────────────────────────────────────────

  Widget _buildResultsBar(TasksProvider provider) {
    final showing = provider.filteredCount;
    final total   = provider.totalCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text('Showing $showing of $total', style: AppTextStyles.bodySmall),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            onPressed: () {
              _searchController.clear();
              AppUtils.hapticSelect();
              provider.clearFilters();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            label: Text('Clear Filters',
              style: AppTextStyles.label.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── Task list ─────────────────────────────────────────────────────────────

  Widget _buildTaskList({
    required TasksProvider    provider,
    required List<TaskModel>  tasks,
    required bool             isEnabled,
  }) {
    if (tasks.isEmpty) {
      final noData = isEnabled
          ? provider.enabledTasks.isEmpty && !provider.hasActiveFilters
          : provider.disabledTasks.isEmpty && !provider.hasActiveFilters;

      if (noData) {
        return EmptyState(
          icon:    isEnabled
              ? Icons.task_alt_rounded
              : Icons.pause_circle_rounded,
          title:   isEnabled ? 'No Enabled Tasks' : 'No Disabled Tasks',
          message: isEnabled
              ? 'All monitoring tasks are currently disabled.'
              : 'All tasks are active. Disable tasks to see them here.',
          color:   isEnabled ? AppColors.primary : null,
        );
      }

      return EmptyState(
        icon:        Icons.filter_list_off_rounded,
        title:       'No Matching Tasks',
        message:     'No ${isEnabled ? "enabled" : "disabled"} tasks match the current filters.',
        color:       AppColors.primary,
        actionLabel: 'Clear Filters',
        onAction: () {
          _searchController.clear();
          provider.clearFilters();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color:     AppColors.primary,
      child: ListView.builder(
        padding:     const EdgeInsets.only(top: 8, bottom: 100),
        itemCount:   tasks.length,
        itemBuilder: (context, index) => _TaskCard(
          task: tasks[index],
        ),
      ),
    );
  }

  // ── Customer reports section ─────────────────────────────────────────────

  Widget _buildCustomerReportsSection(AlertsProvider provider) {
    final reports = provider.activeAlerts
        .where((a) => a.customerReported)
        .toList()
      ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));

    final preview = reports.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Customer Reports', style: AppTextStyles.heading3),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reports.length.toString(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (preview.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.card,
              ),
              child: Text(
                'No customer-reported issues right now.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...preview.map((a) => _CustomerReportCard(alert: a)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TaskCard
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final provider    = context.read<TasksProvider>();
    final typeColor   = _typeColor(task.taskType);
    final statusColor = _statusBlue(task.lastStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            AppUtils.haptic();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: TaskDetailScreen(task: task),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(
                  color: task.enabled ? typeColor : AppColors.textHint,
                  width: 4,
                ),
              ),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: name + status badge ───────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.name, style: AppTextStyles.heading3,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            TasksProvider.taskTypeLabel(task.taskType),
                            style: AppTextStyles.caption.copyWith(
                              color:      typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(task.lastStatus),
                        style: TextStyle(
                          color:      statusColor,
                          fontSize:   10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Bottom row: device, interval, last run, actions ─────
                Row(
                  children: [
                    // Device
                    if (task.deviceName != null) ...[
                      const Icon(Icons.router_rounded,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          task.deviceName!,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      const Icon(Icons.devices_rounded,
                          size: 13, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text('All Devices', style: AppTextStyles.caption),
                      const SizedBox(width: 10),
                    ],

                    // Interval
                    const Icon(Icons.timer_outlined,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(
                      TasksProvider.formatInterval(task.intervalSecs),
                      style: AppTextStyles.caption,
                    ),

                    const Spacer(),

                    // Last run
                    Text(
                      task.lastRun != null
                          ? AppUtils.timeAgo(task.lastRun)
                          : 'Never run',
                      style: AppTextStyles.caption,
                    ),

                    // Quick actions
                    if (task.enabled) ...[
                      const SizedBox(width: 6),
                      _QuickActionButton(
                        icon:    Icons.play_arrow_rounded,
                        color:   AppColors.primary,
                        tooltip: 'Run Now',
                        onTap: () {
                          AppUtils.hapticSelect();
                          provider.runNow(task.id);
                          AppUtils.showSnackbar(
                              context, '${task.name} executed');
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'install': return AppColors.primary;
      case 'survey': return AppColors.primaryLight;
      case 'fault': return AppColors.primaryDark;
      case 'maintenance': return AppColors.primaryLight;
      case 'change': return AppColors.primaryDark;
      case 'audit': return AppColors.primaryLight;
      case 'expansion': return AppColors.primaryDark;
      case 'support': return AppColors.primary;
      case 'marketing': return AppColors.primaryDark;
      default: return AppColors.primaryLight.withOpacity(0.6);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CustomerReportCard
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerReportCard extends StatelessWidget {
  final AlertModel alert;
  const _CustomerReportCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            AppUtils.haptic();
            Navigator.of(context).pushNamed(
              AppConstants.alertDetailRoute,
              arguments: alert,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.report_problem_rounded,
                        size: 16, color: AppColors.primaryDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alert.deviceName,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppUtils.timeAgo(alert.triggeredAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.message,
                  style: AppTextStyles.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _statusBlue(String status) {
  switch (status) {
    case 'completed':
      return AppColors.primary;
    case 'partial':
      return AppColors.primaryLight;
    case 'not_done':
      return AppColors.primaryDark;
    default:
      return AppColors.primaryLight.withOpacity(0.6);
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'completed':
      return 'Completed';
    case 'partial':
      return 'Partially done';
    case 'not_done':
      return 'Not done';
    default:
      return status.replaceAll('_', ' ').trim();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickActionButton
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap:         onTap,
        borderRadius:  BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterChip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final Color?       color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: GestureDetector(
        onTap: () {
          AppUtils.hapticSelect();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:  const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
            color:        selected
                ? accent.withOpacity(0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : AppColors.divider,
              width: selected ? 1.5   : 1.0,
            ),
            boxShadow: selected
                ? []
                : [
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset:     const Offset(0, 1),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize:   12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color:      selected ? accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
