
# Smart ISP Monitor — AI Agent Brief

This file documents the project layout, major components, runtime flow, and
dependencies so an AI agent can quickly understand and work on the codebase.

## 1) Project Summary

Smart ISP Monitor is a full-stack network monitoring system:

- **Backend**: Django REST API providing auth, device inventory, metrics,
	alerts, monitoring tasks, dashboards, and CSV exports.
- **Mobile**: Flutter app with role-based shells (technician, manager,
	customer), JWT auth, and data views for devices, alerts, dashboards, and
	reports.

The system monitors ISP devices, stores time-series metric readings, triggers
alerts when thresholds are breached, and exposes KPIs for different roles.

## 2) Repository Structure (Top-Level)

- backend/  → Django REST API
- mobile/   → Flutter client app
- docs/, lib/, assets/ → Supporting resources (not fully documented here)

### Backend (Django) Structure

- config/      → Django settings and API root routes
- devices/     → Device inventory + device types + status updates
- metrics/     → Metric types, readings, thresholds, snapshots
- alerts/      → Alert rules, alert instances, notification channels
- monitoring/  → Monitoring tasks, reports, dashboards, system health
- users/       → Custom user model, JWT auth, profiles, clients list
- utils/       → SNMP polling + alert engine + scheduler

### Mobile (Flutter) Structure

- lib/main.dart           → App entry (providers + routes)
- lib/core/               → Constants, theme, utilities, widgets
- lib/services/           → API client, DB helper, connectivity, sync stubs
- lib/data/models/        → Device, metric, alert, user, report, task models
- lib/features/           → UI by feature (auth, dashboard, devices, etc.)

## 3) Backend Architecture and Flow

### Settings and Auth

- JWT auth is enforced globally via DRF settings.
- Custom user model: users.CustomUser with a role field.
- CORS is open in DEBUG.
- Database: PostgreSQL (env vars DB_NAME, DB_USER, DB_PASSWORD, DB_HOST, DB_PORT).

### Core Data Models

- **DeviceType** and **Device**: inventory and status.
- **Metric**, **MetricReading**, **MetricThreshold**: time-series data + alert rules.
- **AlertRule**, **Alert**, **NotificationChannel**: alert definitions and history.
- **MonitoringTask**, **MonitoringReport**, **SystemHealth**: monitoring execution and status.
- **CustomUser**: roles (customer, technician, manager, admin).

### API Root Routes (from config/urls.py)

- /api/users/      → auth + profile + clients
- /api/devices/    → device inventory and status
- /api/metrics/    → readings, snapshots, thresholds
- /api/alerts/     → alert lists, rules, channels
- /api/monitoring/ → tasks, reports, health, exports
- /api/dashboard/  → role-specific dashboards

### Key Endpoints (selected)

- Auth: /api/users/register/, /login/, /logout/, /token/refresh/
- Devices: /api/devices/, /my-devices/, /<id>/status/
- Metrics: /api/metrics/?device=, /readings/, /device/<id>/
- Alerts: /api/alerts/, /my-alerts/, /<id>/acknowledge/, /<id>/resolve/
- Monitoring: /api/monitoring/tasks/, /reports/, /health/, /stats/, /export/
- Dashboard: /api/dashboard/summary/, /dashboard/customer/

### Monitoring Logic

- **SNMP polling**: utils/snmp_poller.py queries standard OIDs (uptime, errors).
- **Scheduler**: utils/scheduler.py runs _snmp_cycle every 5 minutes.
- **Alert engine**: utils/alert_engine.py evaluates enabled rules against latest
	metric readings and creates alerts when conditions are met.

### Metric Snapshot Format

The metrics endpoint returns a flat snapshot per device in a structure expected
by the Flutter MetricModel (latency_ms, packet_loss_pct, bandwidth_in_bps, etc.).

## 4) Mobile App Architecture and Flow

### Entry + Routing

- main.dart builds the app with providers and a route factory.
- Routing uses named routes from AppConstants (splash, login, shells, details).

### Role-Based Shells

- TechnicianShell: Home, Devices, Alerts, Settings.
- ManagerShell: Overview, Clients, Reports, Tasks, Settings.
- CustomerShell: My Service, History, Help, Alerts, Settings.

### Auth Flow

- SplashScreen → tryAutoLogin → route by role.
- LoginScreen → AuthProvider.login → navigate to role shell.
- AuthProvider uses AuthService for API calls and SharedPreferences for
	session persistence.

### Demo Mode

AuthProvider has a demo mode toggle:

- _useDummyLogin = true (default in code).
- Bypasses network and accepts demo accounts:
	technician@isp.co.ke / password123
	manager@isp.co.ke / password123
	customer@isp.co.ke / password123

### API Client

- Dio instance with JWT header injection and auto refresh on 401.
- Uses AppConstants.baseUrl = http://127.0.0.1:8000/api
- Parses DRF list or paginated results automatically.
- Provides typed methods for devices, alerts, metrics, tasks, dashboards, and
	report CSV export.

## 5) Dependencies

### Backend (requirements.txt)

- Django
- djangorestframework
- djangorestframework-simplejwt
- django-cors-headers
- psycopg2-binary
- python-dotenv
- Pillow
- pysnmp
- ping3
- psutil
- APScheduler
- pytest, pytest-django

### Mobile (pubspec.yaml)

- dio
- provider
- fl_chart
- sqflite, path
- flutter_local_notifications
- connectivity_plus
- shared_preferences
- get_it
- intl
- cupertino_icons

## 6) Notable Gaps / Stubs (Currently Empty Files)

These files exist but are empty in the current repo snapshot:

- backend/monitoring/tasks.py
- backend/utils/icmp_checker.py
- backend/utils/predictive.py
- mobile/lib/app.dart
- mobile/lib/services/notification_service.dart
- mobile/lib/services/sync_service.dart
- mobile/lib/data/repositories/alert_repository.dart
- mobile/lib/data/repositories/device_repository.dart
- mobile/lib/data/repositories/metric_repository.dart

If implementing features in these areas, check if the logic already exists
elsewhere or if these are planned placeholders.

## 7) Quick Mental Model (End-to-End Flow)

1. Devices are registered and assigned to users.
2. Scheduler polls SNMP metrics on a fixed interval.
3. MetricReadings are persisted.
4. Alert rules evaluate recent readings and create alerts as needed.
5. Mobile app logs in, routes by role, and calls the API for dashboards,
	 devices, alerts, and reports.

