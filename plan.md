# Smart ISP Monitor — Integration & Improvement Plan

## How to read this plan
- `[ ]` — not done
- `[x]` — done / already working
- `[!]` — partially done or has a known issue

---

## Phase 0 — Database Seed (do this first, everything else depends on it)

The backend database is empty. All dummy data in Flutter uses hardcoded IDs
(devices 1–8, alerts 1–8, tasks 1–11) that don't exist on the server.
Every API action will 404 until real rows exist.

- [ ] **0.1 Create a `seed_data` management command** that inserts:
  - 8 devices matching dummy_data.dart IDs and IP addresses
  - 8 alerts (6 active, 2 resolved) matching dummy alert IDs 1–8
  - 11 monitoring tasks matching dummy task IDs 1–11
  - Metric types: latency_ms, packet_loss_pct, bandwidth_in_bps,
    bandwidth_out_bps, cpu_usage_pct, memory_usage_pct, interface_errors,
    uptime_seconds
  - One MetricReading per device per metric type (latest snapshot)
  - 3 test users: technician, manager, customer (matching dummy login accounts)

- [ ] **0.2 Run on a clean DB**
  ```bash
  python manage.py migrate
  python manage.py seed_data
  python manage.py createsuperuser
  ```

---

## Phase 1 — Critical Fixes (blockers)

### 1.1 `DeviceListView` permission leak
`[!]` `DeviceListView` has `permission_classes = [AllowAny]`.
Change to `[IsAuthenticated]` in `backend/devices/views.py`.

### 1.2 `baseUrl` breaks on Android emulator
`[!]` `baseUrl = 'http://127.0.0.1:8000/api'` only works on web/desktop.
Use a build-time define in `mobile/lib/core/constants.dart`:
```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);
```
Run with: `flutter run --dart-define=API_BASE_URL=http://<host-ip>:8000/api`

### 1.3 `ForgotPasswordView` / `ResetPasswordView` missing from backend
`[!]` Routes are registered in `users/urls.py` but the views don't exist in
`users/views.py`. Also `AuthService.forgotPassword()` and
`AuthService.resetPassword()` are called from Flutter but not yet implemented
in `auth_service.dart`.

Need to implement:
- `POST /api/users/forgot-password/` — look up user by email, generate OTP,
  send via existing `send_verification_email` / `issue_email_otp` helpers
- `POST /api/users/reset-password/` — verify OTP, set new password, clear OTP fields
- Add both methods to `mobile/lib/features/auth/auth_service.dart`

### 1.4 `SECRET_KEY` hardcoded in settings
`[!]` Move to `.env` in `backend/config/settings.py`:
```python
SECRET_KEY = os.getenv('DJANGO_SECRET_KEY')
```

---

## Phase 2 — Alerts

### 2.1 Root cause of 404 on acknowledge/resolve
`[x]` URL routing is correct — `/api/alerts/6/acknowledge/` resolves properly.
`[!]` The 404 comes from `Alert.objects.get(pk=6)` — no rows in DB.
**Fix: complete Phase 0 seed first.**

### 2.2 Alert endpoints
`[x]` `GET /api/alerts/` — root route present.
`[x]` `GET /api/alerts/my-alerts/` — customer-scoped, present.
`[x]` `POST /api/alerts/<pk>/acknowledge/` — view exists, needs seeded data.
`[x]` `POST /api/alerts/<pk>/resolve/` — view exists, needs seeded data.

### 2.3 Alert serializer `device_id` field
`[!]` Confirm `AlertSerializer` emits `device_id` as a plain integer.
Flutter casts `json['device_id'] as int` — a nested object will throw.
Add explicitly if missing in `backend/alerts/serializers.py`:
```python
device_id = serializers.IntegerField(source='device.id', read_only=True)
```

### 2.4 Alert `status` → Flutter boolean mapping
`[!]` Verify the `SerializerMethodField` mapping is correct after seeding:

| Backend status | isResolved | isAcknowledged |
|---|---|---|
| `new` | false | false |
| `acknowledged` | false | true |
| `resolved` | true | true |
| `false_positive` | true | true |

---

## Phase 3 — Devices

### 3.1 Device status mismatch
`[!]` Backend choices: `online`, `offline`, `unreachable`, `maintenance`.
Flutter uses `degraded` (not `unreachable`). Map in `DeviceSerializer`:
```python
def get_status(self, obj):
    return 'degraded' if obj.status == 'unreachable' else obj.status
```

### 3.2 `mac_address` and `description` not on Django model
`[!]` Flutter reads both — serializer returns `None` via `SerializerMethodField`.
Fine for now but always empty. Add to model if needed later.

### 3.3 `assigned_to` not writable on device create
`[!]` Technicians creating devices for customers need to pass `assigned_to`.
Add as optional writable field in `DeviceSerializer`.

### 3.4 `DeviceDetailScreen` — latency chart uses dummy history
`[!]` `DeviceDetailProvider.metricsHistory` loads from `DummyData.metricHistory`
as fallback. Wire to `GET /api/metrics/history/<device_id>/` once that endpoint
exists (see Phase 4.2).

### 3.5 `DeviceDetailScreen` — diagnostic history section
`[!]` `DeviceDetailProvider.diagnosticHistory` is populated from local
`DiagnosticSnapshot` objects. Wire to `GET /api/monitoring/reports/?task=<id>`
after Phase 5.3 is done.

### 3.6 `DeviceManagementScreen` — duplicate of `DeviceListScreen`
`[!]` Manager has two device screens: `DeviceManagementScreen` (in manager/)
and `DeviceListScreen` (in devices/). They do the same thing with slightly
different UIs. The manager dashboard opens `DeviceManagementScreen` via
`MaterialPageRoute` instead of switching to the Devices tab.
Decision needed: consolidate into one screen or keep both with clear roles.

---

## Phase 4 — Metrics

### 4.1 `MetricModel` field shape
`[!]` Verify `MetricModel.fromJson` field names match `DeviceMetricSnapshotListView`
output. Snapshot view emits: `id`, `device_id`, `latency_ms`, `packet_loss_pct`,
`bandwidth_in_bps`, `bandwidth_out_bps`, `cpu_usage_pct`, `memory_usage_pct`,
`interface_errors`, `uptime_seconds`, `poll_method`, `recorded_at`.
Flutter must read `recorded_at` (not `timestamp`) and `poll_method`.

### 4.2 Metric history endpoint missing
`[!]` Flutter's device detail latency chart needs a list of flat snapshots
(one per poll interval). The backend has no such endpoint.
Add `GET /api/metrics/history/<device_id>/` returning a list of
`MetricModel`-compatible snapshots ordered by `recorded_at`.

### 4.3 No metric data in DB
`[!]` SNMP poller requires real devices. Seed command (Phase 0) must also
insert `MetricReading` rows so the snapshot view returns data.

---

## Phase 5 — Monitoring Tasks & Reports

### 5.1 `TaskModel` field shape
`[!]` Verify fields match `MonitoringTaskSerializer`. Key checks:
- Flutter reads `device_name` — add to serializer as read-only if missing:
  ```python
  device_name = serializers.CharField(source='device.name', read_only=True, default=None)
  ```
- Flutter reads `interval_secs` — Django model field is `interval`
- Flutter reads `timeout_secs` — Django model field is `timeout`
- Flutter reads `last_status` ✅ matches

### 5.2 `TasksProvider.runNow` — wired but stub only
`[!]` `TasksProvider.runNow(id)` calls `POST /api/monitoring/tasks/<pk>/run/`
which exists but only creates a fake success report without actually running
anything. Wire it to the real SNMP/ping utilities in `utils/`.

### 5.3 `ReportModel` has no backend equivalent
`[!]` Flutter's `ReportsScreen` builds charts from `devices`, `alerts`, and
`metrics` fetched live — it does NOT use `ReportModel` at all. The
`ReportsProvider` loads `getDevices()`, `getAlerts()`, `getMetrics()` and
computes everything client-side. This is already a good approach.
The `ReportModel` in `data/models/report_model.dart` is unused by this screen.
Either remove it or use it for a future saved-reports feature.

### 5.4 Reports CSV export — fully wired
`[x]` `ReportsScreen` export button calls `ApiClient.exportReport()` →
`GET /api/monitoring/export/` → `downloadBytes()`. This is complete.
PDF export shows a "not yet available" snackbar — acceptable for now.

### 5.5 Reports `_UptimeTab` — "Total downtime" is hardcoded
`[!]` `_SlaRow(label: 'Total downtime', value: '3h 24m')` is a hardcoded
string. Compute from resolved alerts' duration or remove the row.

---

## Phase 6 — Dashboard

### 6.1 Technician dashboard — dead code sections
`[!]` `_buildMetricStrip()` (MTTR / Uptime / Alert Velocity) and
`_buildWeeklyChart()` are fully implemented in `technician_dashboard.dart`
but are **never called** in `_buildScrollBody`. Add them back between the
summary cards row and the "Needs Attention" section.

### 6.2 `DashboardSummaryView` — `avg_latency_ms` always 0
`[!]` Hardcoded to `0` in `backend/monitoring/views.py`. Compute from
`MetricReading` for the last hour once metric data exists.

### 6.3 `DashboardProvider` — `weekly_faults` built client-side
`[x]` `DashboardProvider` already builds `_weeklyFaults` from the fetched
alerts list — no backend change needed.

### 6.4 Manager dashboard — navigation inconsistency
`[!]` `ManagerDashboardScreen` opens `DeviceManagementScreen` and
`AlertsScreen` via `MaterialPageRoute` (new stack push) instead of switching
the `ManagerShell` tab. Replace with `ManagerShell.switchTab(context, tabIndex)`.

### 6.5 Manager dashboard — no error/empty state
`[!]` On load failure the screen shows a plain `CircularProgressIndicator`
forever. Add an error state with a retry button (same pattern as
`TechnicianDashboard`).

---

## Phase 7 — Users & Clients

### 7.1 `ClientsProvider` — plan and device data is local only
`[!]` `ClientsProvider` calls `ApiClient.getClients()` for the user list but
`getPlan(id)` and `getDevices(id)` return from `DummyData.clientPlans` and
`DummyData.clientDevices`. Once the backend returns `device_count` and a
`plan` field these should be wired to real data.

Backend needs:
- `device_count` computed field on `UserListSerializer`
- `plan` field on `CustomUser` model (or a separate `Subscription` model)

### 7.2 `ClientDetailScreen` — needs checking
`[ ]` Not yet reviewed. Check that it reads from `ClientsProvider` correctly
and that all actions (edit, assign device) are wired.

### 7.3 `ClientFormScreen` — needs checking
`[ ]` Not yet reviewed. Check that it calls the correct API endpoint to
create/update a customer account.

### 7.4 `UserProfileSerializer` — `full_name` ignored by Flutter
`[!]` Flutter's `UserModel` only reads `username`. The serializer emits
`full_name` but Flutter ignores it. If the UI needs first+last name, add
`first_name` and `last_name` to `UserModel.fromJson`.

### 7.5 Customer "Report Issue" button — no API call
`[!]` `CustomerHomeScreen._showReportDialog` shows a dialog and on submit
just shows a snackbar. It never sends anything to the backend.
Add a `POST /api/alerts/report/` endpoint (or reuse the existing alert
creation flow) and wire the submit button to it.

### 7.6 Customer home — only shows first device
`[!]` `CustomerHomeProvider` sets `_myDevice = devices.first`. Customers
with multiple devices can't see the others. Add a device selector or show
all assigned devices.

---

## Phase 8 — Settings

### 8.1 Settings are in-memory only
`[!]` `SettingsProvider` holds all preferences in memory — they reset on
every app restart. Persist to `SharedPreferences`:
- `pushAlerts`, `pushCriticalOnly`, `pushSystem`
- `compactList`, `refreshInterval`, `autoAcknowledge`
- Dark mode is already persisted via `ThemeProvider` (check this)

### 8.2 "API Endpoint" tile — no edit functionality
`[!]` Tapping "API Endpoint" shows a snackbar saying "coming soon". Wire it
to allow changing `baseUrl` at runtime (useful for switching between dev/prod).

### 8.3 "Send Feedback" — no implementation
`[!]` Shows "coming soon" snackbar. Either implement or remove the tile.

### 8.4 "Delete Account" — no implementation
`[!]` Shows a snackbar directing to admin. Add a `DELETE /api/users/profile/`
endpoint or keep the current message but make it clearer.

---

## Phase 9 — Notifications

### 9.1 `NotificationsScreen` — fully wired
`[x]` Loads from `ApiClient.getMyAlerts()`, maps alerts to
`NotificationItem`, fires local push notifications for new unread alerts,
falls back to `DummyData.notifications` on error. Complete.

### 9.2 No backend `/api/notifications/` endpoint
`[!]` Notifications are derived from alerts client-side. This is fine for
now. A dedicated notifications endpoint would allow server-side read/unread
tracking and system notifications (maintenance windows, etc.).

---

## Phase 10 — Security & Quality

### 10.1 Role-based permissions on backend
`[!]` Most views only check `IsAuthenticated`. Add role guards:

| Endpoint | Allowed roles |
|---|---|
| `POST /api/devices/` | technician, manager, admin |
| `DELETE /api/devices/<pk>/` | manager, admin |
| `GET /api/users/` | admin |
| `GET /api/users/clients/` | manager, admin |
| `POST /api/alerts/rules/` | technician, manager, admin |
| `POST /api/monitoring/tasks/` | technician, manager, admin |

`users/permissions.py` already exists — implement `IsManager`,
`IsTechnician`, `IsAdminUser` there.

### 10.2 Switch to PostgreSQL for production
`[!]` Config already written but commented out in `settings.py`.
Uncomment and drive all values from `.env`.

### 10.3 `ALLOWED_HOSTS` for production
`[!]` Add the real server domain/IP before deploying.

---

## Phase 11 — Cleanup

| Item | Status |
|---|---|
| `features/dashboard/customer_shell.dart` — duplicate, remove it | `[ ]` |
| `technician_dashboard.dart.bak` — delete | `[ ]` |
| `status_budge.dart` typo — rename or remove | `[ ]` |
| `app.dart` is empty — delete and remove import | `[ ]` |
| `SyncService` is empty — implement read-through SQLite cache | `[ ]` |
| `ReportModel` is unused by `ReportsScreen` — remove or repurpose | `[ ]` |
| `diagnostic_screen_new.dart` — decide which version to keep | `[ ]` |
| Pagination — `ApiClient._asList` discards `count` | `[ ]` |
| Periodic alert refresh — `Timer.periodic` every 30s in shells | `[ ]` |
| FCM token registration after login + push dispatch in alert engine | `[ ]` |
| HTTPS / nginx before going live | `[ ]` |

---

## UI Status Summary by Role

### Technician
| Screen | Status | Notes |
|---|---|---|
| Dashboard | `[!]` | MTTR strip + weekly chart built but not rendered |
| Device List | `[x]` | Complete |
| Device Detail | `[x]` | Complete — latency chart uses dummy history fallback |
| Device Form (add/edit) | `[x]` | Complete |
| Diagnostic Screen | `[!]` | Two versions exist — pick one |
| Alerts Screen | `[x]` | Complete |
| Alert Detail | `[x]` | Complete |
| Troubleshoot Screen | `[ ]` | Not yet reviewed |
| Settings | `[!]` | Preferences not persisted |
| Notifications | `[x]` | Complete |

### Manager
| Screen | Status | Notes |
|---|---|---|
| Dashboard (Overview) | `[!]` | No error state; nav uses push instead of tab switch |
| Clients Screen | `[x]` | Complete — plan/device data still from dummy |
| Client Detail | `[ ]` | Not yet reviewed |
| Client Form | `[ ]` | Not yet reviewed |
| Reports Screen | `[x]` | Complete — charts built from live data; CSV export wired |
| Tasks Screen | `[x]` | Complete |
| Task Detail | `[ ]` | Not yet reviewed |
| Task Form | `[ ]` | Not yet reviewed |
| Device Management | `[!]` | Duplicate of Device List; opened via push not tab |
| Manager Settings | `[ ]` | Not yet reviewed |

### Customer
| Screen | Status | Notes |
|---|---|---|
| My Service (Home) | `[!]` | Report button sends nothing; only shows first device |
| Fault History | `[x]` | Complete — wired to `getMyAlerts()` |
| Help Assistant | `[x]` | Complete — fully local, no backend needed |
| Notifications | `[x]` | Complete |
| Settings | `[!]` | Preferences not persisted |

### Admin
| Screen | Status | Notes |
|---|---|---|
| All screens | `[!]` | No dedicated shell — routes to ManagerShell |
| User management | `[ ]` | No UI for admin-only endpoints |

### Shared
| Screen | Status | Notes |
|---|---|---|
| Splash | `[x]` | Complete |
| Login | `[x]` | Complete |
| Register | `[x]` | Complete |
| Email Verify | `[x]` | Complete |
| Forgot Password | `[!]` | UI done — backend views not implemented |
| Reset Password | `[!]` | UI done — backend views not implemented |

---

## Recommended Implementation Order

1. **Phase 0** — seed the database (unblocks everything)
2. **1.1** — fix `DeviceListView` permission
3. **2.3** — confirm alert `device_id` serializer field
4. **3.1** — map `unreachable` → `degraded` in `DeviceSerializer`
5. **5.1** — add `device_name` to `MonitoringTaskSerializer`
6. **4.1** — verify `MetricModel` field names end-to-end
7. **6.1** — add MTTR strip + weekly chart back to technician dashboard
8. **6.4** — fix manager dashboard tab navigation
9. **7.5** — wire customer "Report Issue" to backend
10. **1.3 / 7.2** — implement forgot/reset password views
11. **8.1** — persist settings to `SharedPreferences`
12. **4.2** — add metric history endpoint for device detail chart
13. **Phase 10** — role permissions + secrets
14. **Phase 11** — cleanup
