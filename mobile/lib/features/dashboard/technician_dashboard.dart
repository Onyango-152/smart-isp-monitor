import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/widgets/summary_card.dart';
import '../../core/widgets/device_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/dummy_data.dart';
import '../../features/auth/auth_provider.dart';
import 'dashboard_provider.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {

  @override
  void initState() {
    super.initState();
    // Load dashboard data as soon as the screen is created.
    // We use addPostFrameCallback to wait until the first frame
    // is drawn before triggering a state change — this prevents
    // the "setState called during build" error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,

      // ── App Bar ─────────────────────────────────────────────────────────
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ISP Monitor'),
            Text(
              'Welcome, ${auth.currentUser?.username ?? "Technician"}',
              style: const TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w400,
                color:      Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // Notification bell with active alert badge
          Consumer<DashboardProvider>(
            builder: (context, dashboard, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppConstants.notificationsRoute),
                  ),
                  if (dashboard.criticalAlerts > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width:      8,
                        height:     8,
                        decoration: const BoxDecoration(
                          color: AppColors.severityCritical,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: Consumer<DashboardProvider>(
        builder: (context, dashboard, _) {

          // Loading state — show a full screen spinner
          if (dashboard.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error state
          if (dashboard.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.offline),
                  const SizedBox(height: 12),
                  Text(dashboard.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: dashboard.loadDashboard,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(140, 44)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Loaded state — show the full dashboard
          return RefreshIndicator(
            // Pull down to refresh the dashboard data
            onRefresh: dashboard.refresh,
            child: CustomScrollView(
              slivers: [

                // ── Summary Cards ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Network uptime banner
                        _buildUptimeBanner(dashboard.networkUptime),
                        const SizedBox(height: 16),

                        // Section title
                        const Text(
                          'Network Overview',
                          style: TextStyle(
                            fontSize:   16,
                            fontWeight: FontWeight.bold,
                            color:      AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 2x2 grid of summary cards
                        Row(
                          children: [
                            Expanded(
                              child: SummaryCard(
                                label:           'Total Devices',
                                value:           '${dashboard.totalDevices}',
                                icon:            Icons.router,
                                color:           AppColors.primary,
                                backgroundColor: AppColors.primarySurface,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SummaryCard(
                                label:           'Online',
                                value:           '${dashboard.onlineDevices}',
                                icon:            Icons.check_circle_outline,
                                color:           AppColors.online,
                                backgroundColor: AppColors.onlineLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SummaryCard(
                                label:           'Offline',
                                value:           '${dashboard.offlineDevices}',
                                icon:            Icons.cancel_outlined,
                                color:           AppColors.offline,
                                backgroundColor: AppColors.offlineLight,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SummaryCard(
                                label:           'Active Alerts',
                                value:           '${dashboard.activeAlertsCount}',
                                icon:            Icons.warning_amber_outlined,
                                color:           AppColors.degraded,
                                backgroundColor: AppColors.degradedLight,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Active alerts banner (if any critical alerts exist)
                        if (dashboard.criticalAlerts > 0)
                          _buildCriticalAlertsBanner(
                              dashboard.criticalAlerts, context),

                        const SizedBox(height: 8),

                        // Device list header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'All Devices',
                              style: TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.bold,
                                color:      AppColors.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Device List ────────────────────────────────────────────
                dashboard.devices.isEmpty
                    ? SliverToBoxAdapter(
                        child: EmptyState(
                          title:   'No Devices Found',
                          message: 'Add your first network device to start monitoring.',
                          icon:    Icons.router_outlined,
                          actionLabel: 'Add Device',
                          onAction: () {},
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final device = dashboard.devices[index];
                            // Find the latest metric for this device
                            final metric = DummyData.latestMetrics
                                .where((m) => m.deviceId == device.id)
                                .isNotEmpty
                                ? DummyData.latestMetrics
                                    .firstWhere((m) => m.deviceId == device.id)
                                : null;

                            return DeviceListTile(
                              device:       device,
                              latestMetric: metric,
                              onTap: () => Navigator.of(context).pushNamed(
                                AppConstants.deviceDetailRoute,
                                arguments: device,
                              ),
                            );
                          },
                          childCount: dashboard.devices.length,
                        ),
                      ),

                // Bottom padding so the last card is not hidden by the nav bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
          );
        },
      ),

      // ── Floating Action Button — Add Device ───────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed:       () {},
        backgroundColor: AppColors.primary,
        child:           const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Builds the network uptime banner at the top of the dashboard.
  Widget _buildUptimeBanner(double uptimePct) {
    final color = uptimePct >= 99
        ? AppColors.online
        : uptimePct >= 95
            ? AppColors.degraded
            : AppColors.offline;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Network Uptime',
                  style: TextStyle(
                    fontSize: 12,
                    color:    color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${uptimePct.toStringAsFixed(1)}%  this week',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.bold,
                    color:      color,
                  ),
                ),
              ],
            ),
          ),
          // Uptime progress bar
          SizedBox(
            width:  60,
            height: 60,
            child:  Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value:           uptimePct / 100,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor:      AlwaysStoppedAnimation<Color>(color),
                  strokeWidth:     6,
                ),
                Text(
                  '${uptimePct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.bold,
                    color:      color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the red critical alerts banner shown below the summary cards.
  Widget _buildCriticalAlertsBanner(int count, BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin:  const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color:        AppColors.offlineLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.offline.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_rounded,
                color: AppColors.offline, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count critical alert${count > 1 ? "s" : ""} require your attention',
                style: const TextStyle(
                  color:      AppColors.offline,
                  fontWeight: FontWeight.w600,
                  fontSize:   14,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: AppColors.offline, size: 14),
          ],
        ),
      ),
    );
  }
}