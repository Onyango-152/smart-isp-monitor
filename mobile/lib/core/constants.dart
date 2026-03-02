/// AppConstants holds every fixed value used across the app.
/// Using constants instead of hardcoded strings prevents typos,
/// makes refactoring easier, and keeps all configuration in one place.
class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────────────────────────────────
  static const String appName    = 'ISP Monitor';
  static const String appVersion = '1.0.0';

  // ── API Configuration ────────────────────────────────────────────────────
  // This is the Django backend URL. During development we use localhost.
  // On Android emulator, 10.0.2.2 maps to your computer's localhost.
  // On Chrome, we can use 127.0.0.1 directly.
  static const String baseUrl         = 'http://127.0.0.1:8000/api';
  static const int    connectTimeout  = 30000; // milliseconds
  static const int    receiveTimeout  = 30000;

  // ── API Endpoints ────────────────────────────────────────────────────────
  static const String loginEndpoint          = '/users/login/';
  static const String registerEndpoint       = '/users/register/';
  static const String logoutEndpoint         = '/users/logout/';
  static const String profileEndpoint        = '/users/profile/';
  static const String tokenRefreshEndpoint   = '/users/token/refresh/';
  static const String devicesEndpoint        = '/devices/';
  static const String metricsEndpoint        = '/metrics/';
  static const String alertsEndpoint         = '/alerts/';
  static const String dashboardEndpoint      = '/dashboard/summary/';

  // ── Local Storage Keys ───────────────────────────────────────────────────
  // These are the keys used to store and retrieve values from
  // shared_preferences (the device's local key-value storage).
  static const String tokenKey        = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey         = 'current_user';
  static const String roleKey         = 'user_role';

  // ── Named Routes ─────────────────────────────────────────────────────────
  // Every screen in the app has a named route.
  // Using named routes means you navigate by name rather than
  // directly importing the screen class — this keeps coupling low.
  static const String splashRoute          = '/';
  static const String loginRoute           = '/login';
  static const String technicianHomeRoute  = '/technician';
  static const String managerHomeRoute     = '/manager';
  static const String customerHomeRoute    = '/customer';
  static const String deviceDetailRoute    = '/device-detail';
  static const String diagnosticRoute      = '/diagnostic';
  static const String troubleshootRoute    = '/troubleshoot';
  static const String alertRoute          = '/alerts';
  static const String alertDetailRoute     = '/alert-detail';
  static const String reportsRoute         = '/reports';
  static const String notificationsRoute   = '/notifications';
  static const String settingsRoute        = '/settings';

  // ── User Roles ───────────────────────────────────────────────────────────
  static const String roleAdmin       = 'admin';
  static const String roleTechnician  = 'technician';
  static const String roleManager     = 'manager';
  static const String roleCustomer    = 'customer';

  // ── Device Status Values ─────────────────────────────────────────────────
  static const String statusOnline   = 'online';
  static const String statusOffline  = 'offline';
  static const String statusDegraded = 'degraded';
  static const String statusUnknown  = 'unknown';

  // ── Alert Severity Values ────────────────────────────────────────────────
  static const String severityLow      = 'low';
  static const String severityMedium   = 'medium';
  static const String severityHigh     = 'high';
  static const String severityCritical = 'critical';

  // ── Monitoring ───────────────────────────────────────────────────────────
  // How often the app refreshes dashboard data in seconds
  static const int refreshInterval = 30;
}