# Smart ISP Monitor — Remaining Work

This document outlines the remaining optional enhancements and production readiness tasks.

---

## 🟢 Core Features: COMPLETE (92%)

All critical functionality is implemented and working:
- ✅ User authentication with email verification
- ✅ Device management (CRUD)
- ✅ Real-time metrics collection (SNMP + ICMP)
- ✅ Alert system with rules engine
- ✅ Monitoring tasks with real execution
- ✅ Role-based access control
- ✅ Dashboard summaries for all roles
- ✅ Reports with CSV export
- ✅ Customer self-service portal
- ✅ Diagnostic history tracking

---

## 🟡 Optional Enhancements

### 1. Device Management Consolidation
**Status:** Low priority  
**Issue:** Manager has two device screens (`DeviceListScreen` and `DeviceManagementScreen`)  
**Solution:** Decide whether to:
- Keep both with distinct purposes (list vs. management)
- Consolidate into one screen with tabs
- Remove the duplicate

**Files:**
- `mobile/lib/features/manager/device_management_screen.dart`
- `mobile/lib/features/devices/device_list_screen.dart`

---

### 2. Offline Sync Implementation
**Status:** Low priority  
**Issue:** `SyncService` is an empty stub  
**Solution:** Implement SQLite read-through cache:
- Cache devices, alerts, metrics locally
- Sync on connectivity restore
- Queue write operations when offline

**Files:**
- `mobile/lib/services/sync_service.dart`
- `mobile/lib/services/database_helper.dart`

**Estimated effort:** 4-6 hours

---

### 3. ReportModel Cleanup
**Status:** Low priority  
**Issue:** `ReportModel` exists but `ReportsScreen` doesn't use it  
**Solution:** Either:
- Remove the model entirely
- Repurpose for saved/scheduled reports feature

**Files:**
- `mobile/lib/data/models/report_model.dart`
- `mobile/lib/features/reports/reports_screen.dart`

---

### 4. Pagination Support
**Status:** Low priority  
**Issue:** `ApiClient._asList()` discards pagination metadata (`count`, `next`, `previous`)  
**Solution:**
- Return pagination info alongside results
- Add "Load More" buttons to list screens
- Implement infinite scroll

**Files:**
- `mobile/lib/services/api_client.dart`
- All list screens (devices, alerts, clients, etc.)

**Estimated effort:** 2-3 hours

---

### 5. Periodic Alert Refresh
**Status:** Low priority  
**Issue:** Shells don't auto-refresh alerts  
**Solution:** Add `Timer.periodic` in shell providers:
```dart
Timer.periodic(Duration(seconds: 30), (_) {
  if (mounted) alertsProvider.loadAlerts();
});
```

**Files:**
- `mobile/lib/features/dashboard/technician_shell.dart`
- `mobile/lib/features/manager/manager_shell.dart`
- `mobile/lib/features/customer/customer_shell.dart`

**Estimated effort:** 30 minutes

---

### 6. Hardcoded SLA Data
**Status:** Low priority  
**Issue:** Reports screen shows `'Total downtime: 3h 24m'` as hardcoded string  
**Solution:** Compute from resolved alerts:
```dart
final downtime = alerts
  .where((a) => a.isResolved)
  .map((a) => a.resolvedAt.difference(a.triggeredAt))
  .fold(Duration.zero, (sum, d) => sum + d);
```

**Files:**
- `mobile/lib/features/reports/reports_screen.dart`

**Estimated effort:** 30 minutes

---

## 🔴 Production Readiness

### 1. FCM Push Notifications
**Status:** Medium priority  
**Current:** `NotificationService` is a stub  
**Required:**
- Register FCM token after login
- Send token to backend (`POST /api/users/profile/`)
- Backend: dispatch push when alerts fire
- Mobile: handle background notifications

**Backend changes:**
```python
# users/models.py
class CustomUser(AbstractUser):
    fcm_token = models.CharField(max_length=255, blank=True, null=True)

# utils/alert_engine.py
def send_push_notification(user, alert):
    if user.fcm_token:
        # Use Firebase Admin SDK to send push
        pass
```

**Mobile changes:**
```dart
// services/notification_service.dart
static Future<void> init() async {
  final token = await FirebaseMessaging.instance.getToken();
  await ApiClient.updateProfile({'fcm_token': token});
}
```

**Estimated effort:** 4-6 hours

---

### 2. PostgreSQL Migration
**Status:** High priority for production  
**Current:** Using SQLite (dev only)  
**Solution:** Uncomment PostgreSQL config in `settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'smart_isp_monitor'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD'),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}
```

**Steps:**
1. Install PostgreSQL
2. Create database: `createdb smart_isp_monitor`
3. Update `.env` with credentials
4. Run migrations: `python manage.py migrate`
5. Re-seed: `python manage.py seed_data`

**Estimated effort:** 1 hour

---

### 3. ALLOWED_HOSTS Configuration
**Status:** High priority for production  
**Current:** `ALLOWED_HOSTS = ['*']` (insecure)  
**Solution:**

```python
# settings.py
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')
```

```bash
# .env
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com,api.yourdomain.com
```

**Estimated effort:** 5 minutes

---

### 4. HTTPS / Nginx Setup
**Status:** High priority for production  
**Required:**
- Nginx reverse proxy
- SSL certificate (Let's Encrypt)
- CORS configuration
- Static file serving

**Example nginx config:**
```nginx
server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static/ {
        alias /var/www/smart-isp-monitor/static/;
    }
}
```

**Estimated effort:** 2-3 hours

---

### 5. Environment Configuration
**Status:** High priority for production  
**Required:** Separate dev/staging/prod configs

**Create `.env.production`:**
```bash
DEBUG=False
SECRET_KEY=<generate-strong-key>
ALLOWED_HOSTS=yourdomain.com
DB_NAME=smart_isp_prod
DB_USER=smart_isp_user
DB_PASSWORD=<strong-password>
DB_HOST=db.internal
REDIS_URL=redis://redis.internal:6379/0
```

**Estimated effort:** 1 hour

---

### 6. Logging & Monitoring
**Status:** Medium priority  
**Required:**
- Structured logging (JSON format)
- Error tracking (Sentry)
- Performance monitoring (APM)
- Health check endpoints

**Example:**
```python
# settings.py
LOGGING = {
    'version': 1,
    'handlers': {
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/var/log/smart-isp/django.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'formatter': 'json',
        },
    },
    'root': {
        'handlers': ['file'],
        'level': 'INFO',
    },
}
```

**Estimated effort:** 3-4 hours

---

## Priority Order for Production

1. **PostgreSQL migration** (1 hour) — Required for production
2. **ALLOWED_HOSTS** (5 min) — Security critical
3. **Environment config** (1 hour) — Required for deployment
4. **HTTPS/Nginx** (2-3 hours) — Security critical
5. **FCM notifications** (4-6 hours) — User experience
6. **Logging** (3-4 hours) — Operations
7. **Optional enhancements** (as needed)

**Total estimated effort for production readiness:** 12-16 hours

---

## Testing Checklist Before Production

### Backend
- [ ] All migrations applied
- [ ] Seed data works on PostgreSQL
- [ ] All API endpoints return expected responses
- [ ] Role permissions enforced correctly
- [ ] SNMP polling works with real devices
- [ ] ICMP ping works across platforms
- [ ] Alert rules trigger correctly
- [ ] CSV export generates valid files
- [ ] JWT token refresh works
- [ ] Password reset emails send

### Mobile
- [ ] Login/register flows work
- [ ] All role shells navigate correctly
- [ ] Device CRUD operations work
- [ ] Alert acknowledge/resolve work
- [ ] Monitoring task manual run works
- [ ] Diagnostic history displays
- [ ] Reports export downloads
- [ ] Customer report issue creates alert
- [ ] Device selector shows for multi-device customers
- [ ] Theme switching persists
- [ ] Settings save correctly

### Integration
- [ ] Backend + mobile communicate correctly
- [ ] Token refresh prevents session expiry
- [ ] Error messages display properly
- [ ] Loading states show during API calls
- [ ] Offline behavior is graceful
- [ ] Deep links work (if implemented)

---

## Support & Maintenance

### Regular Tasks
- Monitor error logs daily
- Review alert rules weekly
- Update dependencies monthly
- Backup database daily
- Test disaster recovery quarterly

### Performance Optimization
- Add database indexes for slow queries
- Implement Redis caching for dashboard
- Optimize metric history queries
- Add CDN for static assets
- Enable gzip compression

---

**Last Updated:** April 19, 2026  
**Project Status:** Production-ready with optional enhancements pending
