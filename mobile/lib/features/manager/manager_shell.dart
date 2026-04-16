import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/nav_drawer.dart';
import '../alerts/alerts_provider.dart';
import '../clients/clients_provider.dart';
import '../clients/clients_screen.dart';
import '../devices/device_provider.dart';
import '../tasks/tasks_provider.dart';
import '../tasks/tasks_screen.dart';
import 'device_management_screen.dart';
import 'manager_dashboard_screen.dart';
import 'manager_settings_screen.dart';
import 'reports_screen.dart';

/// ManagerShell — root screen container for manager users.
///
/// Navigation adapts to screen width:
///   ≥ 768 px  → persistent collapsible side NavDrawer, no bottom bar
///   < 768 px  → bottom NavigationBar + hamburger drawer
///
/// Tabs:
///   0  Overview      — KPI dashboard, uptime ring, fleet pie, fault chart
///   1  Clients       — customer account list + details
///   2  Reports       — performance / fault / uptime charts + export
///   3  Tasks         — monitoring tasks list
///   4  Settings      — manager-specific settings + oversight
class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  static void switchTab(BuildContext context, int index) {
    context
        .findAncestorStateOfType<_ManagerShellState>()
        ?._switchTab(index);
  }

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int  _currentIndex  = 0;
  bool _drawerExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _switchTab(int index) => setState(() => _currentIndex = index);
  void _toggleDrawer()       => setState(() => _drawerExpanded = !_drawerExpanded);

  static const double _wideBreakpoint = 768.0;

  // Manager-specific drawer items
  static const List<NavDrawerItem> _managerItems = [
    NavDrawerItem(icon: Icons.dashboard_outlined,    selectedIcon: Icons.dashboard_rounded,    label: 'Overview',       tabIndex: 0),
    NavDrawerItem(icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded,        label: 'Clients',        tabIndex: 1),
    NavDrawerItem(icon: Icons.assessment_outlined,    selectedIcon: Icons.assessment_rounded,    label: 'Reports',        tabIndex: 2),
    NavDrawerItem(icon: Icons.task_alt_outlined,      selectedIcon: Icons.task_alt_rounded,      label: 'Tasks',          tabIndex: 3),
    NavDrawerItem(icon: Icons.settings_outlined,      selectedIcon: Icons.settings_rounded,      label: 'Settings',       tabIndex: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ManagerDashboardProvider()),
        ChangeNotifierProvider(create: (_) => DeviceManagementProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => ClientsProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()..loadAlerts()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: Builder(
        builder: (context) {
          final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
          final alerts = context.watch<AlertsProvider>();

          final content = IndexedStack(
            index: _currentIndex,
            children: const [
              ManagerDashboardScreen(), // 0
              ClientsScreen(),          // 1
              ReportsScreen(),          // 2
              TasksScreen(),            // 3
              ManagerSettingsScreen(),  // 4
            ],
          );

          if (isWide) {
            return Scaffold(
              key: _scaffoldKey,
              body: Row(
                children: [
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
                      roleLabel:         'Manager',
                      items:             _managerItems,
                    ),
                  ),
                  if (_drawerExpanded)
                    const VerticalDivider(width: 1, thickness: 1),
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

          // Narrow: bottom bar + hamburger drawer
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              width: 260,
              child: NavDrawer(
                currentIndex:      _currentIndex,
                onTabSelected:     _switchTab,
                alertCount:        alerts.activeAlerts.length,
                roleLabel:         'Manager',
                items:             _managerItems,
              ),
            ),
            body:                content,
            bottomNavigationBar: _buildNavBar(context),
          );
        },
      ),
    );
  }

  // ── Floating expand button (shown when side drawer is collapsed) ──────────

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
            child: Icon(Icons.menu_rounded, size: 24,
                color: AppColors.textSecondaryOf(context)),
          ),
        ),
      ),
    );
  }

  // ── Bottom navigation bar (narrow screens) ────────────────────────────────

  Widget _buildNavBar(BuildContext context) {
    return NavigationBar(
      selectedIndex:         _currentIndex,
      onDestinationSelected: (i) => setState(() => _currentIndex = i),
      indicatorColor:  AppColors.primarySurfaceOf(context),
      backgroundColor: Theme.of(context).navigationBarTheme.backgroundColor,
      labelBehavior:   NavigationDestinationLabelBehavior.alwaysShow,
      height:          64,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Overview'),
        const NavigationDestination(
          icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Clients'),
        const NavigationDestination(
          icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment_rounded), label: 'Reports'),
        const NavigationDestination(
          icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavBadge — nav icon with optional count badge
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
            right: -6, top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color:        badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
