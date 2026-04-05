import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/nav_drawer.dart';
import '../alerts/alerts_provider.dart';
import '../alerts/alerts_screen.dart';
import '../dashboard/dashboard_provider.dart';
import '../dashboard/technician_dashboard.dart';
import '../devices/device_list_screen.dart';
import '../devices/device_provider.dart';
import '../settings/settings_screen.dart';
import '../reports/reports_provider.dart';
import '../tasks/tasks_provider.dart';

/// TechnicianShell — root screen container for technician users.
///
/// Owns all tab providers via MultiProvider so state is preserved
/// when switching tabs. IndexedStack keeps all screens alive in
/// memory so switching is instant and data is not lost.
///
/// Navigation adapts to screen width:
///   ≥ 768 px  → persistent collapsible side NavDrawer, no bottom bar
///   < 768 px  → bottom NavigationBar + hamburger drawer
///
/// Tabs:  0 Home  |  1 Devices  |  2 Alerts  |  3 Settings
class TechnicianShell extends StatefulWidget {
  const TechnicianShell({super.key});

  /// Allows child screens to switch the active tab from anywhere in
  /// the widget tree without a direct reference to the shell.
  /// Usage: TechnicianShell.switchTab(context, 2) → Alerts tab.
  static void switchTab(BuildContext context, int index) {
    context
        .findAncestorStateOfType<_TechnicianShellState>()
        ?._switchTab(index);
  }

  @override
  State<TechnicianShell> createState() => _TechnicianShellState();
}

class _TechnicianShellState extends State<TechnicianShell> {
  int _currentIndex = 0;
  bool _drawerExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _switchTab(int index) => setState(() => _currentIndex = index);
  void _toggleDrawer() => setState(() => _drawerExpanded = !_drawerExpanded);

  static const double _wideBreakpoint = 768.0;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(
            create: (_) => AlertsProvider()..loadAlerts()),
        ChangeNotifierProvider(create: (_) => TasksProvider()..loadTasks()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
      ],
      child: Builder(
        builder: (context) {
          final isWide =
              MediaQuery.of(context).size.width >= _wideBreakpoint;

          final alerts = context.watch<AlertsProvider>();

          final content = IndexedStack(
            index: _currentIndex,
            children: const [
              TechnicianDashboard(), // 0 — Home
              DeviceListScreen(),    // 1 — Devices
              AlertsScreen(),        // 2 — Alerts
              SettingsScreen(),      // 3 — Settings
            ],
          );

          if (isWide) {
            // ── Wide layout: persistent side drawer + content ──────────
            return Scaffold(
              key: _scaffoldKey,
              body: Row(
                children: [
                  // Animated drawer – collapses to 0 width
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve:    Curves.easeInOutCubic,
                    width:    _drawerExpanded ? NavDrawer.width : 0,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: NavDrawer(
                      currentIndex:      _currentIndex,
                      onTabSelected:     _switchTab,
                      alertCount:        alerts.activeAlerts.length,
                      onToggle:          _toggleDrawer,
                    ),
                  ),
                  if (_drawerExpanded)
                    const VerticalDivider(width: 1, thickness: 1),
                  // Content + overlay hamburger when collapsed
                  Expanded(
                    child: Stack(
                      children: [
                        content,
                        if (!_drawerExpanded)
                          _buildExpandButton(context),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Narrow layout: bottom bar + hamburger drawer ────────────
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              width: 260,
              child: NavDrawer(
                currentIndex:      _currentIndex,
                onTabSelected:     _switchTab,
                alertCount:        alerts.activeAlerts.length,
              ),
            ),
            body:               content,
            bottomNavigationBar: _buildNavBar(context),
          );
        },
      ),
    );
  }

  // ── Floating hamburger shown when side drawer is collapsed ──────────────

  Widget _buildExpandButton(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 6,
      left: 6,
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _toggleDrawer,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.menu_rounded, size: 24, color: AppColors.textSecondaryOf(context)),
          ),
        ),
      ),
    );
  }

  // ── Navigation Bar ────────────────────────────────────────────────────────

  Widget _buildNavBar(BuildContext context) {
    // Consume both providers so only the nav bar rebuilds when
    // alert or notification counts change, not the whole page.
    return Consumer<AlertsProvider>(
      builder: (context, alerts, _) {
        return NavigationBar(
          selectedIndex:         _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          indicatorColor:  AppColors.primarySurfaceOf(context),
          backgroundColor: Theme.of(context).navigationBarTheme.backgroundColor,
          labelBehavior:   NavigationDestinationLabelBehavior.alwaysShow,
          height:          64,
          destinations: [

            // 0. Home
            const NavigationDestination(
              icon:         Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label:        'Home',
            ),

            // 1. Devices
            const NavigationDestination(
              icon:         Icon(Icons.router_outlined),
              selectedIcon: Icon(Icons.router_rounded),
              label:        'Devices',
            ),

            // 2. Alerts — red badge when active alerts exist
            NavigationDestination(
              icon: _NavBadge(
                icon:       Icons.warning_amber_rounded,
                count:      alerts.activeAlerts.length,
                badgeColor: AppColors.offline,
              ),
              selectedIcon: _NavBadge(
                icon:       Icons.warning_rounded,
                count:      alerts.activeAlerts.length,
                badgeColor: AppColors.offline,
                isSelected: true,
              ),
              label: 'Alerts',
            ),
            // 3. Settings
            const NavigationDestination(
              icon:         Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label:        'Settings',
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavBadge — nav icon with an optional count badge
// ─────────────────────────────────────────────────────────────────────────────

class _NavBadge extends StatelessWidget {
  final IconData icon;
  final int      count;
  final Color    badgeColor;
  final bool     isSelected;

  const _NavBadge({
    required this.icon,
    required this.count,
    required this.badgeColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: isSelected ? AppColors.primary : null),
        if (count > 0)
          Positioned(
            right: -6,
            top:   -4,
            child: Container(
              constraints: const BoxConstraints(
                  minWidth: 16, minHeight: 18),
              padding: const EdgeInsets.symmetric(
                  horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color:        badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   9,
                  fontWeight: FontWeight.bold,
                  height:     1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}