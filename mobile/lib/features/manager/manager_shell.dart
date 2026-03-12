import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import 'manager_dashboard_screen.dart';
import 'reports_screen.dart';
import 'device_management_screen.dart';     

/// ManagerShell — main navigation container for manager users.
///
/// Tabs:
///   0  Overview   — KPI dashboard, uptime ring, fleet pie, weekly fault chart
///   1  Devices    — device fleet management (edit, deactivate, reactivate)
///   2  Reports    — performance / fault / uptime charts with date range + export
///   3  Alerts     — notifications feed (shared component)
///   4  Settings   — profile, preferences, logout (shared component)
class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ManagerDashboardProvider()),
        ChangeNotifierProvider(create: (_) => DeviceManagementProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: Consumer<NotificationsProvider>(
        builder: (context, notifications, _) {
          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: const [
                ManagerDashboardScreen(),   // 0 — Overview
                DeviceManagementScreen(),   // 1 — Devices
                ReportsScreen(),            // 2 — Reports
                NotificationsScreen(),      // 3 — Alerts
                SettingsScreen(),           // 4 — Settings
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                  icon:       Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label:      'Overview',
                ),
                const BottomNavigationBarItem(
                  icon:       Icon(Icons.router_outlined),
                  activeIcon: Icon(Icons.router),
                  label:      'Devices',
                ),
                const BottomNavigationBarItem(
                  icon:       Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label:      'Reports',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (notifications.unreadCount > 0)
                        Positioned(
                          right: 0, top: 0,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color:  AppColors.severityCritical,
                              shape:  BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: const Icon(Icons.notifications),
                  label:      'Alerts',
                ),
                const BottomNavigationBarItem(
                  icon:       Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label:      'Settings',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
