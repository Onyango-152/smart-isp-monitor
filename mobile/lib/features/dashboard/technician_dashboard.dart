import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';

import '../../core/widgets/shimmer_skeleton.dart';
import '../../core/widgets/summary_card.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/device_model.dart';
import '../devices/device_provider.dart';
import '../../data/models/metric_model.dart';
import '../../features/auth/auth_provider.dart';
import '../../services/connectivity_provider.dart';
import 'dashboard_provider.dart';
import 'technician_shell.dart';

/// TechnicianDashboard — main landing screen for the technician role.
class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard>
    with TickerProviderStateMixin {

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  Timer? _freshnessTicker;
  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeIn = CurvedAnimation(
      parent: _animCtrl,
      curve:  const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOutCubic));

    // Pulsing animation for status indicators
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard().then((_) {
        if (mounted) _animCtrl.forward();
      });
    });

    _freshnessTicker = Timer.periodic(
      const Duration(seconds: 15),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _freshnessTicker?.cancel();
    _animCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context.read<AuthProvider>()),
      body: Consumer<DashboardProvider>(
        builder: (context, dashboard, _) {

          if (dashboard.isLoading) {
            return ShimmerSkeleton.dashboard();
          }

          if (dashboard.hasError) {
            return EmptyState(
              icon:        Icons.cloud_off_rounded,
              title:       'Could Not Load Dashboard',
              message:     dashboard.errorMessage!,
              color:       AppColors.offline,
              actionLabel: 'Retry',
              onAction:    dashboard.loadDashboard,
            );
          }

          return Column(
            children: [
              const ConnectivityBanner(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: dashboard.refresh,
                  color:     AppColors.primary,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child:   SlideTransition(
                      position: _slideUp,
                      child:    _buildScrollBody(dashboard),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: null,
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AuthProvider auth) {
    final firstName = (auth.currentUser?.username ?? 'Technician')
        .split(' ')
        .first;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      toolbarHeight: 68,
      leading: Builder(
        builder: (ctx) {
          final hasDrawer = Scaffold.maybeOf(ctx)?.hasDrawer ?? false;
          if (!hasDrawer) return const SizedBox.shrink();
          return IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textOnDark),
            onPressed: () { AppUtils.haptic(); Scaffold.of(ctx).openDrawer(); },
          );
        },
      ),
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
          // Frosted avatar circle
          Container(
            width:  42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.textOnDark.withOpacity(0.25),
                  AppColors.textOnDark.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textOnDark.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                firstName[0].toUpperCase(),
                style: const TextStyle(
                  color:      AppColors.textOnDark,
                  fontWeight: FontWeight.bold,
                  fontSize:   17,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_greeting()}, $firstName',
                  style: AppTextStyles.appBarTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Consumer<DashboardProvider>(
                  builder: (_, d, __) => Text(
                    d.lastUpdated != null
                        ? 'Updated ${AppUtils.timeAgo(d.lastUpdated!.toIso8601String())}'
                        : 'Network Operations Centre',
                    style: AppTextStyles.appBarSubtitle.copyWith(
                      fontSize: 11,
                      color: AppColors.textOnDark.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Consumer<DashboardProvider>(
          builder: (context, dashboard, _) => _NotificationBell(
            count: dashboard.criticalAlerts,
            onTap: () {
              AppUtils.haptic();
              TechnicianShell.switchTab(context, 2);
            },
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Scroll body ───────────────────────────────────────────────────────────

  Widget _buildScrollBody(DashboardProvider dashboard) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification && _fabVisible) {
          setState(() => _fabVisible = false);
        } else if (notification is ScrollEndNotification && !_fabVisible) {
          if (notification.metrics.pixels <= 0) {
            setState(() => _fabVisible = true);
          }
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [

        // Hero uptime strip
        SliverToBoxAdapter(child: _buildHeroStrip(dashboard)),

        // Quick summary chips
        SliverToBoxAdapter(child: _buildQuickSummaryRow(dashboard)),

        // Critical banner
        if (dashboard.criticalAlerts > 0)
          SliverToBoxAdapter(
              child: _buildCriticalBanner(dashboard.criticalAlerts)),

        // KPI row
        SliverToBoxAdapter(child: _buildSummaryRow(dashboard)),

        // ── MTTR / Uptime / Alert Velocity ───────────────────────────
        SliverToBoxAdapter(child: _buildMetricStrip(dashboard)),

        // ── Weekly Faults Chart ───────────────────────────────────────
        SliverToBoxAdapter(child: _buildWeeklyChart(dashboard)),

        // ── Needs Attention — priority queue ─────────────────────────
        SliverToBoxAdapter(
          child: SectionHeader(
            title:       'Needs Attention',
            subtitle:    '${dashboard.offlineDevices + dashboard.degradedDevices}'
                ' devices need action',
            actionLabel: 'See All',
            onAction:    () => TechnicianShell.switchTab(context, 1),
          ),
        ),
        dashboard.needsAttention.isEmpty
            ? SliverToBoxAdapter(
                child: EmptyState(
                  icon:    Icons.check_circle_rounded,
                  title:   'All Clear',
                  message: 'Every device is operating normally.',
                  color:   AppColors.online,
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = dashboard.needsAttention[i];
                    return _PriorityQueueTile(
                      rank:     i + 1,
                      device:   item.device,
                      topAlert: item.topAlert,
                      onTap: () => Navigator.of(context).pushNamed(
                        AppConstants.deviceDetailRoute,
                        arguments: item.device,
                      ),
                    );
                  },
                  childCount: dashboard.needsAttention.length,
                ),
              ),

        // ── Fleet Status ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: SectionHeader(
            title:       'Fleet Status',
            subtitle:    '${dashboard.totalDevices} devices monitored',
            actionLabel: 'See All',
            onAction:    () => TechnicianShell.switchTab(context, 1),
          ),
        ),

        dashboard.devices.isEmpty
            ? SliverToBoxAdapter(
                child: EmptyState(
                  icon:        Icons.router_outlined,
                  title:       'No Devices',
                  message:     'No devices are available yet.',
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final device = dashboard.devices[i];
                    final metric = context
                        .read<DeviceProvider>()
                        .getLatestMetric(device.id);
                    return _FleetDeviceCard(
                      device: device,
                      latestMetric: metric,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppConstants.deviceDetailRoute,
                          arguments: device,
                        );
                      },
                    );
                  },
                  childCount: dashboard.devices.length,
                ),
              ),

        // ── Recent Alerts ─────────────────────────────────────────────
        if (dashboard.recentAlerts.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title:       'Recent Alerts',
              subtitle:    '${dashboard.activeAlertsCount} unresolved',
              actionLabel: 'See All',
              onAction:    () => TechnicianShell.switchTab(context, 2),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _AlertPreviewTile(
                alert: dashboard.recentAlerts[i],
                onTap: () => Navigator.of(context).pushNamed(
                  AppConstants.alertDetailRoute,
                  arguments: dashboard.recentAlerts[i],
                ),
              ),
              childCount: dashboard.recentAlerts.length,
            ),
          ),
        ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Hero strip ────────────────────────────────────────────────────────────

  Widget _buildHeroStrip(DashboardProvider dashboard) {
    final uptime = dashboard.networkUptime;
    final label = uptime >= 99
        ? 'Healthy'
        : uptime >= 95
            ? 'Degraded'
            : 'Critical';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.appBarGradientStart,
            AppColors.appBarGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.heroCard,
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textOnDark.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textOnDark.withOpacity(0.03),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurfaceOf(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Network $label',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${uptime.toStringAsFixed(2)}%',
                            style: const TextStyle(
                              color: AppColors.textOnDark,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'network uptime this week',
                            style: TextStyle(
                              color: AppColors.textOnDark.withOpacity(0.6),
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick stat chips row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.textOnDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textOnDark.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HeroStatChip(
                        value: AppUtils.formatLatency(dashboard.avgLatency),
                        label: 'Avg Latency',
                      ),
                      _heroDivider(),
                      _HeroStatChip(
                        value: '${dashboard.activeAlertsCount}',
                        label: 'Open Alerts',
                      ),
                      _heroDivider(),
                      _HeroStatChip(
                        value: '${dashboard.faultsThisWeek}',
                        label: 'Faults',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.textOnDark.withOpacity(0.12),
    );
  }

  // ── Quick summary chips ─────────────────────────────────────────────────

  Widget _buildQuickSummaryRow(DashboardProvider dashboard) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryChip(
            label: 'Total Devices',
            value: '${dashboard.totalDevices}',
          ),
          _SummaryChip(
            label: 'Degraded',
            value: '${dashboard.degradedDevices}',
          ),
          _SummaryChip(
            label: 'Faults',
            value: '${dashboard.faultsThisWeek}',
          ),
        ],
      ),
    );
  }

  // ── Summary cards row ─────────────────────────────────────────────────────

  Widget _buildSummaryRow(DashboardProvider dashboard) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(child: SummaryCard(
            label:           'Online',
            value:           '${dashboard.onlineDevices}',
            intValue:        dashboard.onlineDevices,
            icon:            Icons.check_circle_rounded,
            color:           AppColors.primary,
            backgroundColor: AppColors.primarySurface,
            showIcon:        false,
          )),
          const SizedBox(width: 10),
          Expanded(child: SummaryCard(
            label:           'Offline',
            value:           '${dashboard.offlineDevices}',
            intValue:        dashboard.offlineDevices,
            icon:            Icons.cancel_rounded,
            color:           AppColors.primary,
            backgroundColor: AppColors.primarySurface,
            showIcon:        false,
          )),
          const SizedBox(width: 10),
          Expanded(child: SummaryCard(
            label:           'Alerts',
            value:           '${dashboard.activeAlertsCount}',
            intValue:        dashboard.activeAlertsCount,
            icon:            Icons.warning_rounded,
            color:           AppColors.primary,
            backgroundColor: AppColors.primarySurface,
            showBadge:       dashboard.criticalAlerts > 0,
            onTap:           () => TechnicianShell.switchTab(context, 2),
            showIcon:        false,
          )),
        ],
      ),
    );
  }

  // ── MTTR · Uptime · Alert Velocity strip ──────────────────────────────────

  Widget _buildMetricStrip(DashboardProvider dashboard) {
    final mttr = dashboard.mttrMinutes;
    final trend = dashboard.mttrTrendPct;
    final velocity = dashboard.alertsLastHour;
    final velocityHigh = dashboard.alertVelocityHigh;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        // MTTR Card
        Expanded(child: _MetricTile(
          label: 'MTTR',
          value: mttr > 0 ? '${mttr.toStringAsFixed(0)}m' : '—',
          accentColor: AppColors.primary,
          progress: mttr > 0 ? (1 - (mttr / 120).clamp(0.0, 1.0)) : null,
          trailing: trend != 0
              ? _TrendChip(
                  value: '${trend.abs().toStringAsFixed(0)}%',
                  isPositive: trend > 0,
                )
              : null,
        )),
        const SizedBox(width: 10),
        // Uptime Card
        Expanded(child: _MetricTile(
          label: 'Uptime',
          value: '${dashboard.networkUptime.toStringAsFixed(1)}%',
          accentColor: AppColors.primary,
          progress: dashboard.networkUptime / 100,
        )),
        const SizedBox(width: 10),
        // Alert Velocity Card
        Expanded(child: _MetricTile(
          label: 'Last Hour',
          value: '$velocity alert${velocity != 1 ? "s" : ""}',
          accentColor: AppColors.primary,
          trailing: _TrendChip(
            value: velocityHigh ? 'Above avg' : 'Quieter',
            isPositive: !velocityHigh,
          ),
        )),
      ]),
    );
  }

  // ── Critical alert banner ─────────────────────────────────────────────────

  Widget _buildCriticalBanner(int count) {
    return GestureDetector(
      onTap: () {
        AppUtils.haptic();
        TechnicianShell.switchTab(context, 2);
      },
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppShadows.card,
          ),
          child: child,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count critical alert${count > 1 ? "s" : ""} '
                    'need attention',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Tap to view and resolve →',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Weekly faults bar chart ───────────────────────────────────────────────

  Widget _buildWeeklyChart(DashboardProvider dashboard) {
    final faults = dashboard.weeklyFaults;
    if (faults.isEmpty) return const SizedBox.shrink();

    final maxVal = faults
        .map((f) => f['faults'] as int)
        .fold(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly Faults', style: AppTextStyles.heading3),
                      Text(
                        '${dashboard.faultsThisWeek} total this week',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bar chart
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: faults.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final f = entry.value;
                  final count = f['faults'] as int;
                  final isToday = f['isToday'] as bool;
                  final barH =
                      maxVal > 0 ? (count / maxVal) * 62.0 : 4.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isToday || count == maxVal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: AppColors.textOnDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration:
                                Duration(milliseconds: 400 + idx * 60),
                            curve: Curves.easeOutCubic,
                            height: barH.clamp(4.0, 62.0),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.primarySurfaceOf(context),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isToday
                                ? 'Today'
                                : _shortDay(f['date'] as String),
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  String _shortDay(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[dt.weekday % 7];
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StaggeredItem — delayed fade+slide entrance for list items
// ─────────────────────────────────────────────────────────────────────────────

class _StaggeredItem extends StatefulWidget {
  final Widget child; final Duration delay;
  const _StaggeredItem({required this.child, required this.delay});
  @override State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _AlertPreviewTile — compact alert row for the dashboard preview section
// ─────────────────────────────────────────────────────────────────────────────

class _AlertPreviewTile extends StatelessWidget {
  final AlertModel   alert;
  final VoidCallback onTap;
  const _AlertPreviewTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    final bg    = AppColors.primarySurfaceOf(context);

    return GestureDetector(
      onTap: () { AppUtils.haptic(); onTap(); },
      child: Container(
        margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alert.deviceName,
                            style: AppTextStyles.heading3,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        AppUtils.severityLabel(alert.severity).toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(alert.message,
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppUtils.timeAgo(alert.triggeredAt),
                    style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetricTile — compact card for MTTR / Uptime / Alert Velocity
// ─────────────────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String   label;
  final String   value;
  final Color?   accentColor;
  final double?  progress;
  final Widget?  trailing;

  const _MetricTile({
    required this.label,
    required this.value,
    this.accentColor,
    this.progress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(value,
            style: AppTextStyles.heading3.copyWith(fontSize: 15)),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: (accentColor ?? AppColors.primary).withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                    accentColor ?? AppColors.primary),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PriorityQueueTile — ranked "needs attention" row with inline alert message
// ─────────────────────────────────────────────────────────────────────────────

class _PriorityQueueTile extends StatelessWidget {
  final int          rank;
  final DeviceModel  device;
  final AlertModel?  topAlert;
  final VoidCallback onTap;

  const _PriorityQueueTile({
    required this.rank,
    required this.device,
    required this.topAlert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline   = device.status == AppConstants.statusOffline;

    return GestureDetector(
      onTap: () { AppUtils.haptic(); onTap(); },
      child: Container(
        margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device name + alert message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.name,
                          style: AppTextStyles.heading3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        isOffline ? 'OFFLINE' : 'DEGRADED',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (topAlert != null) ...[
                    Text(
                      topAlert!.message,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${device.ipAddress}'
                          '${device.location != null ? "  ·  ${device.location}" : ""}',
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FleetDeviceCard — compact device card for the Fleet Status dashboard section
// ─────────────────────────────────────────────────────────────────────────────

class _FleetDeviceCard extends StatelessWidget {
  final DeviceModel device;
  final MetricModel? latestMetric;
  final VoidCallback onTap;

  const _FleetDeviceCard({
    required this.device,
    this.latestMetric,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppUtils.haptic();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + status badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.name,
                          style: AppTextStyles.heading3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        device.status.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // IP + type
                  Text(
                    '${device.ipAddress}  ·  '
                    '${AppUtils.deviceTypeLabel(device.deviceType)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (device.lastSeen != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last seen ${AppUtils.timeAgo(device.lastSeen)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SummaryChip — compact KPI chip
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.labelBold.copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationBell — animated notification icon with count badge
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.textOnDark),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.textOnDark, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AnimatedUptimeRing — circular progress with custom paint and glow
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedUptimeRing extends StatefulWidget {
  final double uptime;
  final Color ringColor;
  const _AnimatedUptimeRing({required this.uptime, required this.ringColor});

  @override
  State<_AnimatedUptimeRing> createState() => _AnimatedUptimeRingState();
}

class _AnimatedUptimeRingState extends State<_AnimatedUptimeRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = Tween<double>(begin: 0, end: widget.uptime / 100).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(
            progress: _progress.value,
            color: widget.ringColor,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.uptime.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  'uptime',
                  style: TextStyle(
                    color: AppColors.textOnDark.withOpacity(0.6),
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = AppColors.textOnDark.withOpacity(0.12),
    );

    // Progress arc
    final sweepAngle = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // Glow
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..color = color.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeroStatChip — stat item inside the hero strip bottom bar
// ─────────────────────────────────────────────────────────────────────────────

class _HeroStatChip extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStatChip({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textOnDark.withOpacity(0.5),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TrendChip — small green/red chip showing trend direction
// ─────────────────────────────────────────────────────────────────────────────

class _TrendChip extends StatelessWidget {
  final String value;
  final bool isPositive;
  const _TrendChip({required this.value, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}