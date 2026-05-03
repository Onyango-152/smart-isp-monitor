import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_skeleton.dart';
import '../../data/models/alert_model.dart';
import 'alerts_provider.dart';

/// AlertsScreen shows all network alerts in two tabs: Active and Resolved.
///
/// Features:
///   - Gradient AppBar with active alert count badge
///   - Severity filter chip row (All / Critical / High / Medium / Low)
///   - Active tab: acknowledge + resolve quick action buttons
///   - Resolved tab: resolved-at timestamp
///   - Pull-to-refresh on both tabs
///   - Error state via EmptyState
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;
  String _severityFilter = 'all';
  String _sourceFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().loadAlerts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: provider.isSelectMode
              ? _buildSelectAppBar(provider)
              : _buildAppBar(),
          body: _buildBody(provider),
          bottomNavigationBar: provider.isSelectMode
              ? _buildBulkActionBar(provider)
              : null,
        );
      },
    );
  }

  Widget _buildBody(AlertsProvider provider) {
          if (provider.isLoading) {
            return ShimmerSkeleton.alertList(animate: false);
          }

          if (provider.hasError) {
            return EmptyState(
              icon:        Icons.cloud_off_rounded,
              title:       'Could Not Load Alerts',
              message:     provider.errorMessage!,
              color:       AppColors.primary,
              animate:     false,
              actionLabel: 'Retry',
              onAction:    provider.loadAlerts,
            );
          }

          final activeFiltered   = _filterAlerts(provider.activeAlerts);
          final resolvedFiltered = _filterAlerts(provider.resolvedAlerts);

          return Column(
            children: [
              _buildSeverityRow(provider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAlertList(
                      context:  context,
                      provider: provider,
                      alerts:   activeFiltered,
                      isActive: true,
                    ),
                    _buildAlertList(
                      context:  context,
                      provider: provider,
                      alerts:   resolvedFiltered,
                      isActive: false,
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  // ── Select mode App Bar ───────────────────────────────────────────────────

  PreferredSizeWidget _buildSelectAppBar(AlertsProvider provider) {
    return AppBar(
      leading: TextButton(
        onPressed: provider.exitSelectMode,
        child: const Text('Close',
            style: TextStyle(color: AppColors.textOnDark)),
      ),
      title: Text('${provider.selectedCount} selected'),
      actions: [
        TextButton(
          onPressed: () => provider.selectAll(
            _filterAlerts(provider.activeAlerts),
          ),
          child: const Text('Select All',
              style: TextStyle(color: AppColors.textOnDark)),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Bulk action bar ───────────────────────────────────────────────────────

  Widget _buildBulkActionBar(AlertsProvider provider) {
    return Container(
      padding:    const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        boxShadow: [
          BoxShadow(
            color:      AppColors.dividerOf(context).withOpacity(0.6),
            blurRadius: 8,
            offset:     const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: provider.selectedCount == 0
                    ? null
                    : () {
                        provider.acknowledgeSelected();
                        AppUtils.showSnackbar(
                            context, 'Selected alerts acknowledged');
                      },
                child: const Text('Acknowledge'),
                style: OutlinedButton.styleFrom(
                  minimumSize:     const Size(0, 46),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: provider.selectedCount == 0
                    ? null
                    : () {
                        provider.resolveSelected();
                        AppUtils.showSnackbar(
                            context, 'Selected alerts resolved');
                      },
                child: const Text('Resolve'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
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
      title: Consumer<AlertsProvider>(
        builder: (_, provider, __) => Row(
          children: [
            const Text('Alerts',
                style: TextStyle(color: AppColors.textOnDark)),
            if (provider.activeAlerts.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.activeAlerts.length}',
                  style: const TextStyle(
                    color:      AppColors.textOnDark,
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Consumer<AlertsProvider>(
          builder: (_, provider, __) => TextButton(
            onPressed: provider.isLoading ? null : () {
              AppUtils.haptic();
              provider.refresh();
            },
            child: const Text('Refresh',
                style: TextStyle(color: AppColors.textOnDark)),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: _buildTabBar(),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller:           _tabController,
      labelColor:           AppColors.textOnDark,
      unselectedLabelColor: AppColors.textOnDark.withOpacity(0.6),
      indicatorColor:       AppColors.textOnDark,
      indicatorWeight:      3,
      tabs: [
        Consumer<AlertsProvider>(
          builder: (_, provider, __) => Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Active'),
                if (provider.criticalCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${provider.criticalCount}',
                      style: const TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.textOnDark,
                      ),
                    ),
                  ),
                ] else if (provider.activeAlerts.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppColors.textOnDark.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${provider.activeAlerts.length}',
                      style: const TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.bold,
                        color:      AppColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Consumer<AlertsProvider>(
          builder: (_, provider, __) => Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Resolved'),
                if (provider.resolvedAlerts.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppColors.textOnDark.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${provider.resolvedAlerts.length}',
                      style: const TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Severity filter row ───────────────────────────────────────────────────

  Widget _buildSeverityRow(AlertsProvider provider) {
    return Container(
      color: AppColors.surfaceOf(context),
      child: SizedBox(
        height: 46,
        child: ListView(
          padding:         const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          children: [
            _SeverityChip(
              label:    'Customer Reported',
              selected: _sourceFilter == 'customer',
              color:    AppColors.primaryDark,
              badgeCount: provider.customerReportedCount,
              onTap:    () => setState(() {
                _sourceFilter =
                    _sourceFilter == 'customer' ? 'all' : 'customer';
                if (_sourceFilter == 'customer') {
                  _severityFilter = 'all';
                }
              }),
            ),
            _SeverityChip(
              label:    'All',
              selected: _severityFilter == 'all',
              onTap:    () => setState(() {
                _severityFilter = 'all';
                _sourceFilter = 'all';
              }),
            ),
            _SeverityChip(
              label:    'Critical',
              selected: _severityFilter == AppConstants.severityCritical,
              color:    AppColors.primary,
              onTap:    () => setState(() {
                _severityFilter = AppConstants.severityCritical;
                _sourceFilter = 'all';
              }),
            ),
            _SeverityChip(
              label:    'High',
              selected: _severityFilter == AppConstants.severityHigh,
              color:    AppColors.primary,
              onTap:    () => setState(() {
                _severityFilter = AppConstants.severityHigh;
                _sourceFilter = 'all';
              }),
            ),
            _SeverityChip(
              label:    'Medium',
              selected: _severityFilter == AppConstants.severityMedium,
              color:    AppColors.primary,
              onTap:    () => setState(() {
                _severityFilter = AppConstants.severityMedium;
                _sourceFilter = 'all';
              }),
            ),
            _SeverityChip(
              label:    'Low',
              selected: _severityFilter == AppConstants.severityLow,
              color:    AppColors.primary,
              onTap:    () => setState(() {
                _severityFilter = AppConstants.severityLow;
                _sourceFilter = 'all';
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Alert list ────────────────────────────────────────────────────────────

  Widget _buildAlertList({
    required BuildContext     context,
    required AlertsProvider   provider,
    required List<AlertModel> alerts,
    required bool             isActive,
  }) {
    if (alerts.isEmpty) {
      final baseList = isActive
          ? provider.activeAlerts
          : provider.resolvedAlerts;
      final sourceFiltered = _sourceFilter == 'customer'
          ? baseList.where((a) => a.customerReported).toList()
          : baseList;
      final noData = sourceFiltered.isEmpty;

      if (noData) {
        return EmptyState(
          icon:    isActive
              ? Icons.check_circle_rounded
              : Icons.history_rounded,
          title:   isActive ? 'All Clear'         : 'No Resolved Alerts',
          message: isActive
              ? 'All devices are operating normally.\nNo issues require your attention.'
              : 'Resolved alerts will appear here.',
          color:   AppColors.primary,
          animate: false,
        );
      }

      // Data exists but filtered out
      return EmptyState(
        icon:        Icons.filter_list_off_rounded,
        title:       'No Matching Alerts',
        message:     'No ${isActive ? "active" : "resolved"} alerts match the current filters.',
        color:       AppColors.primary,
        animate:     false,
        actionLabel: 'Show All',
        onAction:    () => setState(() {
          _severityFilter = 'all';
          _sourceFilter = 'all';
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color:     AppColors.primary,
      child: ListView.builder(
        padding:     const EdgeInsets.only(top: 8, bottom: 80),
        itemCount:   alerts.length,
        itemBuilder: (context, index) => _AlertCard(
          alert:    alerts[index],
          isActive: isActive,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<AlertModel> _filterAlerts(List<AlertModel> alerts) {
    if (_sourceFilter == 'customer') {
      return alerts.where((a) => a.customerReported).toList();
    }
    if (_severityFilter == 'all') return alerts;
    return alerts.where((a) => a.severity == _severityFilter).toList();
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1).toLowerCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// _SeverityChip
// ─────────────────────────────────────────────────────────────────────────────

class _SeverityChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final Color?       color;
  final int?         badgeCount;

  const _SeverityChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? AppColors.primary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: GestureDetector(
        onTap: () { AppUtils.hapticSelect(); onTap(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:  const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
            color:        selected 
                ? accent.withOpacity(0.12) 
                : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : AppColors.dividerOf(context),
              width: selected ? 1.5   : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:      selected ? accent : AppColors.textSecondaryOf(context),
                ),
              ),
              if (badgeCount != null && badgeCount! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? accent : AppColors.dividerOf(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount!.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertCard
// ─────────────────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final bool       isActive;

  const _AlertCard({required this.alert, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color    = AppColors.primary;
    final provider = context.watch<AlertsProvider>();
    final inSelectMode = provider.isSelectMode;
    final isSelected   = provider.selectedIds.contains(alert.id);

    final card = GestureDetector(
      onTap: () {
        AppUtils.haptic();
        if (inSelectMode) {
          provider.toggleSelection(alert.id);
        } else {
          Navigator.of(context).pushNamed(
            AppConstants.alertDetailRoute,
            arguments: alert,
          );
        }
      },
      onLongPress: isActive && !inSelectMode
          ? () {
              AppUtils.haptic();
              provider.enterSelectMode(alert.id);
            }
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color:        isSelected
              ? AppColors.primarySurfaceOf(context)
              : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border:       Border(
            left: BorderSide(
              color: isDark ? AppColors.primaryLight : color, 
              width: 4,
            ),
          ),
          boxShadow:    AppShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Top row: checkbox / icon, type, severity badge, time ──
              Row(
                children: [
                  if (inSelectMode) ...[
                    _MiniPill(
                      label: isSelected ? 'SELECTED' : 'SELECT',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      alert.alertType.replaceAll('_', ' ').toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color:         isDark ? AppColors.primaryLight : color,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _MiniPill(label: 'ALERT', color: AppColors.primary),
                  if (alert.customerReported) ...[
                    const SizedBox(width: 6),
                    _MiniPill(label: 'CUSTOMER', color: AppColors.primaryDark),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    AppUtils.timeAgo(alert.triggeredAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              // ── Message ───────────────────────────────────────────────
              Text(
                alert.message, 
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),

              const SizedBox(height: 8),

              // ── Bottom row: device, pills, actions ────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alert.deviceName,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // ACK / RESOLVED pills
                  if (alert.isAcknowledged && !alert.isResolved)
                    _MiniPill(label: 'ACK',      color: AppColors.primary),
                  if (alert.isResolved) ...[
                    _MiniPill(label: 'RESOLVED', color: AppColors.primary),
                    if (alert.resolvedAt != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        AppUtils.timeAgo(alert.resolvedAt!),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ],

                  // Quick action buttons — active unresolved alerts only
                  if (isActive && !alert.isResolved)
                    Consumer<AlertsProvider>(
                      builder: (context, provider, _) => Row(
                        children: [
                          const SizedBox(width: 6),
                          if (!alert.isAcknowledged)
                            _QuickActionButton(
                              label:   'Ack',
                              onTap: () {
                                AppUtils.hapticSelect();
                                provider.acknowledgeAlert(alert.id);
                                AppUtils.showSnackbar(
                                    context, 'Alert acknowledged');
                              },
                            ),
                          const SizedBox(width: 5),
                          _QuickActionButton(
                            label:   'Resolve',
                            onTap: () {
                              AppUtils.hapticSelect();
                              provider.resolveAlert(alert.id);
                              AppUtils.showSnackbar(
                                  context, 'Alert resolved');
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // ── Swipe actions for active, unresolved alerts ──
    if (!isActive || alert.isResolved || inSelectMode) return card;

    return Dismissible(
      key: ValueKey('alert-swipe-${alert.id}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right → Acknowledge
          if (!alert.isAcknowledged) {
            provider.acknowledgeAlert(alert.id);
            AppUtils.showSnackbar(context, 'Alert acknowledged');
          }
        } else {
          // Swipe left → Resolve
          provider.resolveAlert(alert.id);
          AppUtils.showSnackbar(context, 'Alert resolved');
        }
        return false; // keep the widget in place; state change redraws it
      },
      background: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Text('Acknowledge',
          style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Text('Resolve',
          style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      child: card,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniPill
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPill extends StatelessWidget {
  final String label;
  final Color  color;
  const _MiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color:      isDark ? AppColors.primaryLight : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickActionButton
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        AppColors.primarySurfaceOf(context),
          borderRadius: BorderRadius.circular(7),
          border:       Border.all(
            color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
