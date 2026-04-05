import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'services/connectivity_provider.dart';
import 'features/alerts/alert_detail_screen.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/email_verify_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/customer/customer_shell.dart';
import 'features/dashboard/technician_shell.dart';
import 'features/devices/device_detail_screen.dart';
import 'features/devices/device_form_screen.dart';
import 'features/devices/diagnostic_screen.dart';
import 'features/manager/manager_shell.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/reports/report_detail_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/clients/client_form_screen.dart';
import 'features/tasks/task_form_screen.dart';
import 'features/troubleshoot/troubleshoot_screen.dart';

void main() {
  runApp(const SmartISPApp());
}

class SmartISPApp extends StatelessWidget {
  const SmartISPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title:                      AppConstants.appName,
          theme:                      AppTheme.lightTheme,
          darkTheme:                  AppTheme.darkTheme,
          themeMode:                  themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          initialRoute:               AppConstants.splashRoute,
          onGenerateRoute:            _onGenerateRoute,
        ),
      ),
    );
  }

  // ── Route factory ──────────────────────────────────────────────────────────
  //
  // Transition conventions:
  //   _fadeRoute  — splash, login, shell roots (no directional history)
  //   _slideRoute — detail/modal screens pushed on top of a shell tab

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {

      // Auth & splash
      case AppConstants.splashRoute:
        return _fadeRoute(settings, const SplashScreen());
      case AppConstants.loginRoute:
        return _fadeRoute(settings, const LoginScreen());
      case AppConstants.registerRoute:
        return _slideRoute(settings, const RegisterScreen());
      case AppConstants.verifyEmailRoute:
        return _slideRoute(settings, const EmailVerifyScreen());

      // Role shells — fade in, no directional entry
      case AppConstants.technicianHomeRoute:
        return _fadeRoute(settings, const TechnicianShell());
      case AppConstants.managerHomeRoute:
        return _fadeRoute(settings, const ManagerShell());
      case AppConstants.customerHomeRoute:
        return _fadeRoute(settings, const CustomerShell());

      // Detail screens — slide from right
      case AppConstants.deviceDetailRoute:
        return _slideRoute(settings, const DeviceDetailScreen());
      case AppConstants.deviceFormRoute:
        return _slideRoute(settings, const DeviceFormScreen());
      case AppConstants.diagnosticRoute:
        return _slideRoute(settings, const DiagnosticScreen());
      case AppConstants.troubleshootRoute:
        return _slideRoute(settings, const TroubleshootScreen());
      case AppConstants.alertDetailRoute:
        return _slideRoute(settings, const AlertDetailScreen());
      case AppConstants.reportsRoute:
        return _slideRoute(settings, const ReportDetailScreen());
      case AppConstants.taskFormRoute:
        return _slideRoute(settings, const TaskFormScreen());
      case AppConstants.clientFormRoute:
        return _slideRoute(settings, const ClientFormScreen());

      // Standalone notifications route — used for push notification deep links.
      // Inside TechnicianShell the screen is already covered by the shell's
      // MultiProvider; this wrapping is only for the standalone entry point.
      case AppConstants.notificationsRoute:
        return _slideRoute(
          settings,
          ChangeNotifierProvider(
            create: (_) => NotificationsProvider(),
            child:  const NotificationsScreen(),
          ),
        );

      // Fallback
      default:
        return _fadeRoute(settings, const LoginScreen());
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route transition helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Fade — for top-level switches: splash → login → shell.
PageRoute<T> _fadeRoute<T>(RouteSettings settings, Widget page) {
  return PageRouteBuilder<T>(
    settings:           settings,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder:        (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(
          parent: animation, curve: Curves.easeInOut),
      child: child,
    ),
  );
}

/// Slide from right — for detail screens pushed over a tab.
PageRoute<T> _slideRoute<T>(RouteSettings settings, Widget page) {
  return PageRouteBuilder<T>(
    settings:           settings,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder:        (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end:   Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child:    child,
      );
    },
  );
}