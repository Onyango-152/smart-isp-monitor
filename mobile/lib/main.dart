import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_isp_monitor/features/devices/diagnostic_screen_new.dart';
import 'features/alerts/alert_screen.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/dashboard/technician_shell.dart';
import 'features/dashboard/manager_shell.dart';
import 'features/dashboard/customer_shell.dart';
import 'features/devices/device_provider.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/devices/device_detail_screen.dart';
import 'features/troubleshoot/troubleshoot_screen.dart';

void main() {
  runApp(const SmartISPApp());
}

class SmartISPApp extends StatelessWidget {
  const SmartISPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // MultiProvider registers all our state management providers
      // at the top of the widget tree so any screen below can access them.
      providers: [
        // AuthProvider — manages login state and the current user
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // DeviceProvider — manages the device list, search, and filters
        // ChangeNotifierProxyProvider is used here instead of plain
        // ChangeNotifierProvider because in the future DeviceProvider
        // will need the auth token from AuthProvider to make API calls.
        // For now it works the same as a regular provider.
        ChangeNotifierProvider(create: (_) => DeviceProvider()),

        // DashboardProvider — manages the dashboard summary statistics
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,

        // initialRoute tells Flutter which screen to show first
        initialRoute: AppConstants.splashRoute,

        // onGenerateRoute handles navigation to named routes.
        // It reads the route name and returns the correct screen.
        // We use onGenerateRoute instead of the simpler 'routes' map
        // because some routes need to pass arguments to the next screen.
        onGenerateRoute: (settings) {
          switch (settings.name) {
                        case AppConstants.alertRoute:
                          final alerts = settings.arguments as List<dynamic>? ?? [];
                          return MaterialPageRoute(
                            builder: (_) => AlertScreen(alerts: alerts.cast()),
                          );
            case AppConstants.splashRoute:
              return MaterialPageRoute(
                builder: (_) => const SplashScreen(),
              );

            case AppConstants.loginRoute:
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );

            case AppConstants.technicianHomeRoute:
              return MaterialPageRoute(
                builder: (_) => const TechnicianShell(),
              );

            case AppConstants.troubleshootRoute:
              return MaterialPageRoute(
                builder: (_) => const TroubleshootScreen(),
              );

            case AppConstants.managerHomeRoute:
              return MaterialPageRoute(
                builder: (_) => const ManagerShell(),
              );
            case AppConstants.deviceDetailRoute:
              return MaterialPageRoute(
                builder: (_) => const DeviceDetailScreen(),
              );

            case AppConstants.diagnosticRoute:
              return MaterialPageRoute(
                builder: (_) => const DiagnosticScreen(), // from diagnostic_screen_new.dart
              );

            case AppConstants.customerHomeRoute:
              return MaterialPageRoute(
                builder: (_) => const CustomerShell(),
              );

            // Default fallback — show login if route not found
            default:
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );
          }
        },
      ),
    );
  }
}
