/// AppConstants holds every fixed value used across the app.
/// Using constants instead of hardcoded strings prevents typos,
/// makes refactoring easier, and keeps all configuration in one place.
class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────────────────────────────────
  static const String appName    = 'ISP Monitor';
  static const String appVersion = '1.0.0';

  // ── API Configuration ────────────────────────────────────────────────────
  static const String baseUrl        = 'http://127.0.0.1:8000/api';
  static const int    connectTimeout = 30000;
  static const int    receiveTimeout = 30000;

  // ── API Endpoints ────────────────────────────────────────────────────────
  static const String loginEndpoint        = '/users/login/';
  static const String registerEndpoint     = '/users/register/';
  static const String logoutEndpoint       = '/users/logout/';
  static const String profileEndpoint      = '/users/profile/';
  static const String tokenRefreshEndpoint = '/users/token/refresh/';
  static const String devicesEndpoint         = '/devices/';
  static const String myDevicesEndpoint       = '/devices/my-devices/';
  static const String metricsEndpoint         = '/metrics/';
  static const String alertsEndpoint          = '/alerts/';
  static const String myAlertsEndpoint        = '/alerts/my-alerts/';
  static const String tasksEndpoint           = '/monitoring/tasks/';
  static const String clientsEndpoint         = '/users/clients/';
  static const String dashboardEndpoint       = '/dashboard/summary/';
  static const String customerDashboardEndpoint = '/dashboard/customer/';

  // ── Local Storage Keys ───────────────────────────────────────────────────
  static const String tokenKey        = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey         = 'current_user';
  static const String roleKey         = 'user_role';

  // ── Named Routes ─────────────────────────────────────────────────────────
  static const String splashRoute         = '/';
  static const String loginRoute          = '/login';
  static const String registerRoute       = '/register';
  static const String technicianHomeRoute = '/technician';
  static const String managerHomeRoute    = '/manager';
  static const String customerHomeRoute   = '/customer';
  static const String deviceDetailRoute   = '/device-detail';
  static const String deviceFormRoute     = '/device-form';
  static const String diagnosticRoute     = '/diagnostic';
  static const String troubleshootRoute   = '/troubleshoot';
  static const String alertRoute          = '/alerts';
  static const String alertDetailRoute    = '/alert-detail';
  static const String reportsRoute        = '/reports';
  static const String taskFormRoute        = '/task-form';
  static const String clientFormRoute      = '/client-form';
  static const String notificationsRoute   = '/notifications';
  static const String settingsRoute       = '/settings';

  // ── User Roles ───────────────────────────────────────────────────────────
  static const String roleAdmin      = 'admin';
  static const String roleTechnician = 'technician';
  static const String roleManager    = 'manager';
  static const String roleCustomer   = 'customer';

  // ── Device Status Values ─────────────────────────────────────────────────
  static const String statusOnline   = 'online';
  static const String statusOffline  = 'offline';
  static const String statusDegraded = 'degraded';
  static const String statusUnknown  = 'unknown';

  // ── Device Type Values ───────────────────────────────────────────────────
  static const String deviceRouter      = 'router';
  static const String deviceSwitch      = 'switch';
  static const String deviceOlt         = 'olt';
  static const String deviceAccessPoint = 'access_point';

  // ── Alert Severity Values ────────────────────────────────────────────────
  static const String severityCritical = 'critical';
  static const String severityHigh     = 'high';
  static const String severityMedium   = 'medium';
  static const String severityLow      = 'low';
  static const String severityInfo     = 'info';

  // ── Monitoring ───────────────────────────────────────────────────────────
  static const int refreshInterval = 30;
}
