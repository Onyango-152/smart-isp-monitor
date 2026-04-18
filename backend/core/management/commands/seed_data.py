"""
seed_data — populates the database with realistic test data that matches
the Flutter DummyData exactly (same IDs, names, IPs, statuses).

Usage:
    python manage.py seed_data           # seed everything
    python manage.py seed_data --flush   # wipe then re-seed
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta

User = get_user_model()


def _ago(**kwargs):
    return timezone.now() - timedelta(**kwargs)


class Command(BaseCommand):
    help = 'Seed the database with test data matching Flutter DummyData'

    def add_arguments(self, parser):
        parser.add_argument('--flush', action='store_true',
                            help='Delete existing seed data before inserting')

    def handle(self, *args, **options):
        if options['flush']:
            self._flush()

        self._seed_users()
        self._seed_devices()
        self._seed_metric_types()
        self._seed_metric_readings()
        self._seed_alert_rules()
        self._seed_alerts()
        self._seed_tasks()
        self.stdout.write(self.style.SUCCESS('Database seeded successfully.'))

    # ── Flush ─────────────────────────────────────────────────────────────────

    def _flush(self):
        from alerts.models import Alert, AlertRule
        from devices.models import Device, DeviceType
        from metrics.models import Metric, MetricReading
        from monitoring.models import MonitoringTask
        Alert.objects.all().delete()
        AlertRule.objects.all().delete()
        MetricReading.objects.all().delete()
        MonitoringTask.objects.all().delete()
        Device.objects.all().delete()
        DeviceType.objects.all().delete()
        Metric.objects.all().delete()
        User.objects.filter(username__in=[
            'technician', 'manager', 'customer']).delete()
        self.stdout.write('Existing seed data flushed.')

    # ── Users ─────────────────────────────────────────────────────────────────

    def _seed_users(self):
        users = [
            dict(id=1, username='technician', email='technician@isp.co.ke',
                 first_name='John', last_name='Kamau',
                 role='technician', password='password123'),
            dict(id=2, username='manager', email='manager@isp.co.ke',
                 first_name='Grace', last_name='Wanjiru',
                 role='manager', password='password123'),
            dict(id=3, username='customer', email='customer@isp.co.ke',
                 first_name='Peter', last_name='Otieno',
                 role='customer', password='password123'),
        ]
        for u in users:
            if User.objects.filter(username=u['username']).exists():
                self.stdout.write(f"  User '{u['username']}' already exists, skipping.")
                continue
            user = User.objects.create_user(
                username=u['username'],
                email=u['email'],
                password=u['password'],
                first_name=u['first_name'],
                last_name=u['last_name'],
                role=u['role'],
                email_verified=True,
            )
            self.stdout.write(f"  Created user: {user.username} ({user.role})")

    # ── Devices ───────────────────────────────────────────────────────────────

    def _seed_devices(self):
        from devices.models import Device, DeviceType

        types = {}
        for name in ['Router', 'Switch', 'OLT', 'Access Point']:
            dt, _ = DeviceType.objects.get_or_create(name=name)
            types[name] = dt

        customer = User.objects.filter(username='customer').first()

        devices = [
            dict(id=1, name='Core Router',      ip='192.168.1.1',
                 dtype='Router',       status='online',
                 location='Server Room',
                 snmp='public', last_seen=_ago(minutes=5)),
            dict(id=2, name='Access Switch A',  ip='192.168.1.10',
                 dtype='Switch',       status='online',
                 location='Distribution Cabinet — Block A',
                 snmp='public', last_seen=_ago(minutes=5)),
            dict(id=3, name='OLT-01',           ip='192.168.1.20',
                 dtype='OLT',          status='unreachable',
                 location='Data Centre',
                 snmp='public', last_seen=_ago(minutes=10)),
            dict(id=4, name='AP — Rooftop',     ip='192.168.1.30',
                 dtype='Access Point', status='offline',
                 location='Rooftop Tower',
                 snmp='', last_seen=_ago(hours=1, minutes=25)),
            dict(id=5, name='Backup Router',    ip='192.168.1.5',
                 dtype='Router',       status='online',
                 location='Server Room',
                 snmp='private', last_seen=_ago(minutes=5)),
            dict(id=6, name='Access Switch B',  ip='192.168.1.11',
                 dtype='Switch',       status='online',
                 location='Distribution Cabinet — Block B',
                 snmp='public', last_seen=_ago(minutes=7)),
            dict(id=7, name='OLT-02',           ip='192.168.1.21',
                 dtype='OLT',          status='online',
                 location='Data Centre',
                 snmp='public', last_seen=_ago(minutes=5)),
            dict(id=8, name='AP — Block C',     ip='192.168.1.31',
                 dtype='Access Point', status='unreachable',
                 location='Block C Corridor',
                 snmp='public', last_seen=_ago(minutes=15)),
        ]

        for d in devices:
            obj, created = Device.objects.update_or_create(
                id=d['id'],
                defaults=dict(
                    name=d['name'],
                    ip_address=d['ip'],
                    device_type=types[d['dtype']],
                    status=d['status'],
                    location=d['location'],
                    snmp_community=d['snmp'] or None,
                    last_seen=d['last_seen'],
                    assigned_to=customer if d['id'] in (1, 4) else None,
                ),
            )
            self.stdout.write(f"  {'Created' if created else 'Updated'} device: {obj.name}")

    # ── Metric types ──────────────────────────────────────────────────────────

    def _seed_metric_types(self):
        from metrics.models import Metric
        metric_defs = [
            ('latency_ms',        'ms'),
            ('packet_loss_pct',   '%'),
            ('bandwidth_in_bps',  'bps'),
            ('bandwidth_out_bps', 'bps'),
            ('cpu_usage_pct',     '%'),
            ('memory_usage_pct',  '%'),
            ('interface_errors',  'count'),
            ('uptime_seconds',    's'),
        ]
        for name, unit in metric_defs:
            m, created = Metric.objects.get_or_create(name=name, defaults={'unit': unit})
            self.stdout.write(f"  {'Created' if created else 'Exists'} metric type: {m.name}")

    # ── Metric readings ───────────────────────────────────────────────────────

    def _seed_metric_readings(self):
        from devices.models import Device
        from metrics.models import Metric, MetricReading

        snapshots = {
            1: dict(latency_ms=12.4,  packet_loss_pct=0.0,  bandwidth_in_bps=45000000,
                    bandwidth_out_bps=38000000, cpu_usage_pct=34.0, memory_usage_pct=52.0,
                    interface_errors=0,  uptime_seconds=864000),
            2: dict(latency_ms=8.1,   packet_loss_pct=0.0,  bandwidth_in_bps=12000000,
                    bandwidth_out_bps=9500000,  cpu_usage_pct=18.0, memory_usage_pct=31.0,
                    interface_errors=2,  uptime_seconds=432000),
            3: dict(latency_ms=245.0, packet_loss_pct=8.5,  bandwidth_in_bps=5000000,
                    bandwidth_out_bps=4200000,  cpu_usage_pct=78.0, memory_usage_pct=85.0,
                    interface_errors=24, uptime_seconds=259200),
            4: dict(latency_ms=None,  packet_loss_pct=100.0, bandwidth_in_bps=None,
                    bandwidth_out_bps=None,     cpu_usage_pct=None, memory_usage_pct=None,
                    interface_errors=None, uptime_seconds=None),
            5: dict(latency_ms=15.2,  packet_loss_pct=0.0,  bandwidth_in_bps=8000000,
                    bandwidth_out_bps=6500000,  cpu_usage_pct=22.0, memory_usage_pct=44.0,
                    interface_errors=0,  uptime_seconds=600000),
            6: dict(latency_ms=9.8,   packet_loss_pct=0.0,  bandwidth_in_bps=14000000,
                    bandwidth_out_bps=11000000, cpu_usage_pct=21.0, memory_usage_pct=28.0,
                    interface_errors=0,  uptime_seconds=518400),
            7: dict(latency_ms=11.0,  packet_loss_pct=0.1,  bandwidth_in_bps=22000000,
                    bandwidth_out_bps=19000000, cpu_usage_pct=41.0, memory_usage_pct=60.0,
                    interface_errors=1,  uptime_seconds=720000),
            8: dict(latency_ms=188.0, packet_loss_pct=3.2,  bandwidth_in_bps=3000000,
                    bandwidth_out_bps=2400000,  cpu_usage_pct=67.0, memory_usage_pct=72.0,
                    interface_errors=9,  uptime_seconds=172800),
        }

        metric_map = {m.name: m for m in Metric.objects.all()}

        for device_id, values in snapshots.items():
            try:
                device = Device.objects.get(id=device_id)
            except Device.DoesNotExist:
                continue
            for metric_name, value in values.items():
                if value is None:
                    continue
                metric = metric_map.get(metric_name)
                if not metric:
                    continue
                MetricReading.objects.create(device=device, metric=metric, value=value)
            self.stdout.write(f"  Created metric readings for device {device_id}")

        # 7-day latency history for OLT-01 (device 3) — used by detail chart
        latency_metric = metric_map.get('latency_ms')
        if latency_metric:
            device3 = Device.objects.filter(id=3).first()
            if device3:
                for day in range(7):
                    MetricReading.objects.create(
                        device=device3,
                        metric=latency_metric,
                        value=80.0 + day * 25.0,
                    )

    # ── Alert rules ───────────────────────────────────────────────────────────

    def _seed_alert_rules(self):
        from devices.models import Device
        from metrics.models import Metric
        from alerts.models import AlertRule

        latency = Metric.objects.filter(name='latency_ms').first()
        packet  = Metric.objects.filter(name='packet_loss_pct').first()
        memory  = Metric.objects.filter(name='memory_usage_pct').first()
        errors  = Metric.objects.filter(name='interface_errors').first()
        cpu     = Metric.objects.filter(name='cpu_usage_pct').first()

        rules = [
            dict(name='High Latency',      device_id=3, metric=latency, condition='gt',
                 threshold=200, severity='high'),
            dict(name='Packet Loss',       device_id=3, metric=packet,  condition='gt',
                 threshold=5,   severity='high'),
            dict(name='High Memory',       device_id=3, metric=memory,  condition='gt',
                 threshold=80,  severity='high'),
            dict(name='Interface Errors',  device_id=8, metric=errors,  condition='gt',
                 threshold=5,   severity='medium'),
            dict(name='Elevated Latency',  device_id=8, metric=latency, condition='gt',
                 threshold=150, severity='medium'),
            dict(name='Minor Errors',      device_id=1, metric=errors,  condition='gt',
                 threshold=1,   severity='low'),
            dict(name='High CPU',          device_id=2, metric=cpu,     condition='gt',
                 threshold=85,  severity='low'),
        ]

        for r in rules:
            device = Device.objects.filter(id=r['device_id']).first()
            if not device or not r['metric']:
                continue
            AlertRule.objects.get_or_create(
                name=r['name'],
                defaults=dict(device=device, metric=r['metric'],
                              condition=r['condition'], threshold=r['threshold'],
                              severity=r['severity'], enabled=True),
            )
        self.stdout.write(f"  Created {len(rules)} alert rules")

    # ── Alerts ────────────────────────────────────────────────────────────────

    def _seed_alerts(self):
        from devices.models import Device
        from alerts.models import Alert, AlertRule

        technician = User.objects.filter(username='technician').first()

        alert_data = [
            dict(id=1, device_id=4, rule_name=None,
                 severity='critical', status='new',
                 message='AP — Rooftop (192.168.1.30) is unreachable.',
                 triggered_at=_ago(hours=1, minutes=25)),
            dict(id=2, device_id=3, rule_name='High Latency',
                 severity='high', status='acknowledged',
                 message='High latency on OLT-01: 245 ms (threshold: 200 ms)',
                 triggered_at=_ago(minutes=40),
                 acknowledged_by=technician,
                 acknowledged_at=_ago(minutes=35)),
            dict(id=3, device_id=3, rule_name='Packet Loss',
                 severity='high', status='new',
                 message='Packet loss on OLT-01: 8.5% (threshold: 5%)',
                 triggered_at=_ago(minutes=38)),
            dict(id=4, device_id=3, rule_name='High Memory',
                 severity='high', status='new',
                 message='High memory usage on OLT-01: 85% (threshold: 80%)',
                 triggered_at=_ago(minutes=35)),
            dict(id=5, device_id=8, rule_name='Elevated Latency',
                 severity='medium', status='new',
                 message='Elevated latency on AP — Block C: 188 ms',
                 triggered_at=_ago(minutes=20)),
            dict(id=6, device_id=8, rule_name='Interface Errors',
                 severity='medium', status='new',
                 message='Interface errors on AP — Block C: 9 errors/min',
                 triggered_at=_ago(minutes=18)),
            dict(id=7, device_id=1, rule_name='Minor Errors',
                 severity='low', status='resolved',
                 message='Minor interface errors on Core Router: 2 errors',
                 triggered_at=_ago(hours=8),
                 resolved_at=_ago(hours=7, minutes=15)),
            dict(id=8, device_id=2, rule_name='High CPU',
                 severity='low', status='resolved',
                 message='Briefly high CPU on Access Switch A: 91% (now resolved)',
                 triggered_at=_ago(days=1),
                 resolved_at=_ago(hours=23)),
        ]

        for a in alert_data:
            device = Device.objects.filter(id=a['device_id']).first()
            if not device:
                continue
            rule = AlertRule.objects.filter(name=a['rule_name']).first() if a.get('rule_name') else None
            defaults = dict(
                device=device,
                rule=rule,
                severity=a['severity'],
                status=a['status'],
                message=a['message'],
                triggered_at=a['triggered_at'],
                acknowledged_by=a.get('acknowledged_by'),
                acknowledged_at=a.get('acknowledged_at'),
                resolved_at=a.get('resolved_at'),
            )
            obj, created = Alert.objects.update_or_create(id=a['id'], defaults=defaults)
            self.stdout.write(f"  {'Created' if created else 'Updated'} alert {obj.id}: {obj.message[:50]}")

    # ── Monitoring tasks ──────────────────────────────────────────────────────

    def _seed_tasks(self):
        from devices.models import Device
        from monitoring.models import MonitoringTask

        tasks = [
            dict(id=1,  name='Core Router SNMP Poll',    device_id=1, task_type='snmp',
                 interval=300, timeout=5, enabled=True,
                 last_run=_ago(minutes=5), last_status='success'),
            dict(id=2,  name='OLT-01 SNMP Poll',         device_id=3, task_type='snmp',
                 interval=300, timeout=5, enabled=True,
                 last_run=_ago(minutes=10), last_status='success'),
            dict(id=3,  name='AP Rooftop Ping',           device_id=4, task_type='ping',
                 interval=60,  timeout=3, enabled=True,
                 last_run=_ago(minutes=1), last_status='failed'),
            dict(id=4,  name='All Devices Ping Sweep',    device_id=None, task_type='ping',
                 interval=120, timeout=3, enabled=True,
                 last_run=_ago(minutes=2), last_status='success'),
            dict(id=5,  name='Gateway HTTP Health',       device_id=1, task_type='http',
                 interval=600, timeout=10, enabled=True,
                 last_run=_ago(minutes=10), last_status='success'),
            dict(id=6,  name='DNS Resolution Check',      device_id=None, task_type='dns',
                 interval=300, timeout=5, enabled=True,
                 last_run=_ago(minutes=5), last_status='success'),
            dict(id=7,  name='Switch A TCP Port Check',   device_id=2, task_type='tcp',
                 interval=300, timeout=5, enabled=True,
                 last_run=_ago(minutes=5), last_status='success'),
            dict(id=8,  name='OLT-02 SNMP Poll',          device_id=7, task_type='snmp',
                 interval=300, timeout=5, enabled=True,
                 last_run=_ago(minutes=5), last_status='success'),
            dict(id=9,  name='Block C AP Ping',            device_id=8, task_type='ping',
                 interval=60,  timeout=3, enabled=True,
                 last_run=_ago(minutes=1), last_status='success'),
            dict(id=10, name='Backup Router SNMP Poll',   device_id=5, task_type='snmp',
                 interval=600, timeout=5, enabled=False,
                 last_run=_ago(days=7), last_status='success'),
            dict(id=11, name='Switch B HTTP Portal',      device_id=6, task_type='http',
                 interval=600, timeout=10, enabled=False,
                 last_run=_ago(days=3), last_status='failed'),
        ]

        for t in tasks:
            device = Device.objects.filter(id=t['device_id']).first() if t['device_id'] else None
            obj, created = MonitoringTask.objects.update_or_create(
                id=t['id'],
                defaults=dict(
                    name=t['name'],
                    device=device,
                    task_type=t['task_type'],
                    interval=t['interval'],
                    timeout=t['timeout'],
                    enabled=t['enabled'],
                    last_run=t['last_run'],
                    last_status=t['last_status'],
                ),
            )
            self.stdout.write(f"  {'Created' if created else 'Updated'} task: {obj.name}")
