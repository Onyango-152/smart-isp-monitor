import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import 'technician_dashboard.dart';
import 'dashboard_provider.dart';
import '../devices/device_list_screen.dart';
import '../devices/device_detail_screen.dart';
import '../devices/device_provider.dart';

class TechnicianShell extends StatefulWidget {
  const TechnicianShell({super.key});

  @override
  State<TechnicianShell> createState() => _TechnicianShellState();
}

class _TechnicianShellState extends State<TechnicianShell> {
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // Providers registered here are scoped to the technician shell.
      // They are created once when the shell appears and destroyed
      // when the shell is removed from the widget tree.
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0 — Home
            _buildNavWithNavigator(
              0,
              _navigatorKeys[0],
              (_) => const TechnicianDashboard(),
            ),
            // Tab 1 — Devices
            _buildNavWithNavigator(
              1,
              _navigatorKeys[1],
              (_) => const DeviceListScreen(),
            ),
            // Tab 2 — Alerts
            _buildNavWithNavigator(
              2,
              _navigatorKeys[2],
              (_) => const _PlaceholderScreen(
                  label: 'Alerts', icon: Icons.notifications_active),
            ),
            // Tab 3 — Notifications
            _buildNavWithNavigator(
              3,
              _navigatorKeys[3],
              (_) => const _PlaceholderScreen(
                  label: 'Notifications', icon: Icons.notifications),
            ),
            // Tab 4 — Settings
            _buildNavWithNavigator(
              4,
              _navigatorKeys[4],
              (_) => const _PlaceholderScreen(
                  label: 'Settings', icon: Icons.settings),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // If tapping the same tab, pop to root of that tab's navigator
            if (index == _currentIndex) {
              _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.router_outlined),
                activeIcon: Icon(Icons.router),
                label: 'Devices'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_active_outlined),
                activeIcon: Icon(Icons.notifications_active),
                label: 'Alerts'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                activeIcon: Icon(Icons.notifications),
                label: 'Notifications'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings'),
          ],
        ),
      ),
    );
  }

  /// Builds a Navigator for each tab with its own navigation stack.
  /// This allows each tab to maintain its own navigation history.
  Widget _buildNavWithNavigator(
    int tabIndex,
    GlobalKey<NavigatorState> navigatorKey,
    WidgetBuilder homeBuilder,
  ) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        // Routes specific to this tab
        switch (settings.name) {
          case null:
          case '/':
            return MaterialPageRoute(builder: homeBuilder);

          case AppConstants.deviceDetailRoute:
            return MaterialPageRoute(
              builder: (_) => const DeviceDetailScreen(),
              settings: settings,
            );

          default:
            return MaterialPageRoute(builder: homeBuilder);
        }
      },
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _PlaceholderScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textSecondary,
                )),
            const SizedBox(height: 8),
            const Text('Coming in the next session',
                style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}