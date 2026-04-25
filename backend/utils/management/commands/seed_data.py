"""
Django management command to seed the database with realistic test data.

Usage:
    python manage.py seed_data
    python manage.py seed_data --clear  # Clear existing data first
"""
import random
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.db import transaction
from organisations.models import Organisation, Membership
from devices.models import Device, DeviceType
from metrics.models import Metric, MetricReading, MetricThreshold, MetricPrediction
from alerts.models import Alert, AlertRule, NotificationChannel

User = get_user_model()


class Command(BaseCommand):
    help = 'Seeds the database with realistic test data'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing data before seeding',
        )

    def handle(self, *args, **options):
        if options['clear']:
            self.stdout.write(self.style.WARNING('Clearing existing data...'))
            self.clear_data()

        self.stdout.write(self.style.SUCCESS('Starting data seeding...'))
        
        with transaction.atomic():
            # Create base data
            users = self.create_users()
            orgs = self.create_organisations(users)
            self.create_memberships(users, orgs)
            device_types = self.create_device_types()
            metrics = self.create_metrics()
            devices = self.create_devices(device_types, orgs)
            
            # Create monitoring data
            self.create_metric_thresholds(devices, metrics)
            self.create_metric_readings(devices, metrics)
            self.create_predictions(devices, metrics)
            
            # Create alerts
            alert_rules = self.create_alert_rules(devices, metrics)
            self.create_alerts(alert_rules, devices, users)
            self.create_notification_channels(users)

        self.stdout.write(self.style.SUCCESS('✓ Data seeding completed successfully!'))
        self.print_summary(users, orgs, devices)

    def clear_data(self):
        """Clear all existing data"""
        Alert.objects.all().delete()
        AlertRule.objects.all().delete()
        NotificationChannel.objects.all().delete()
        MetricPrediction.objects.all().delete()
        MetricReading.objects.all().delete()
        MetricThreshold.objects.all().delete()
        Device.objects.all().delete()
        DeviceType.objects.all().delete()
        Metric.objects.all().delete()
        Membership.objects.all().delete()
        Organisation.objects.all().delete()
        User.objects.filter(is_superuser=False).delete()
        self.stdout.write(self.style.SUCCESS('✓ Existing data cleared'))

    def create_users(self):
        """Create diverse set of users with different roles"""
        self.stdout.write('Creating users...')
        users = []
        
        # Admin user
        admin, created = User.objects.get_or_create(
            username='admin',
            defaults={
                'email': 'admin@example.com',
                'first_name': 'Admin',
                'last_name': 'User',
                'role': User.ADMIN,
                'is_staff': True,
                'is_superuser': True,
                'email_verified': True,
            }
        )
        if created:
            admin.set_password('admin123')
            admin.save()
        users.append(admin)
        
        # Managers
        manager_names = [
            ('John', 'Smith', 'john.smith'),
            ('Sarah', 'Johnson', 'sarah.johnson'),
            ('Michael', 'Brown', 'michael.brown'),
        ]
        for first, last, username in manager_names:
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': f'{username}@example.com',
                    'first_name': first,
                    'last_name': last,
                    'role': User.MANAGER,
                    'phone': f'+1-555-{random.randint(1000, 9999)}',
                    'email_verified': True,
                }
            )
            if created:
                user.set_password('password123')
                user.save()
            users.append(user)
        
        # Technicians
        tech_names = [
            ('David', 'Wilson', 'david.wilson'),
            ('Emma', 'Davis', 'emma.davis'),
            ('James', 'Miller', 'james.miller'),
            ('Olivia', 'Garcia', 'olivia.garcia'),
            ('William', 'Martinez', 'william.martinez'),
            ('Sophia', 'Rodriguez', 'sophia.rodriguez'),
        ]
        for first, last, username in tech_names:
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': f'{username}@example.com',
                    'first_name': first,
                    'last_name': last,
                    'role': User.TECHNICIAN,
                    'phone': f'+1-555-{random.randint(1000, 9999)}',
                    'email_verified': True,
                }
            )
            if created:
                user.set_password('password123')
                user.save()
            users.append(user)
        
        # Customers
        customer_names = [
            ('Robert', 'Anderson', 'robert.anderson'),
            ('Jennifer', 'Taylor', 'jennifer.taylor'),
            ('Daniel', 'Thomas', 'daniel.thomas'),
            ('Lisa', 'Moore', 'lisa.moore'),
            ('Matthew', 'Jackson', 'matthew.jackson'),
            ('Emily', 'White', 'emily.white'),
            ('Christopher', 'Harris', 'christopher.harris'),
            ('Amanda', 'Martin', 'amanda.martin'),
        ]
        for first, last, username in customer_names:
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': f'{username}@example.com',
                    'first_name': first,
                    'last_name': last,
                    'role': User.CUSTOMER,
                    'phone': f'+1-555-{random.randint(1000, 9999)}',
                    'email_verified': True,
                }
            )
            if created:
                user.set_password('password123')
                user.save()
            users.append(user)
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(users)} users'))
        return users

    def create_organisations(self, users):
        """Create multiple organisations"""
        self.stdout.write('Creating organisations...')
        orgs = []
        
        org_data = [
            ('TechCorp Solutions', 'techcorp-solutions', 'Enterprise IT solutions provider'),
            ('Global Networks Inc', 'global-networks', 'International network infrastructure'),
            ('CloudFirst Systems', 'cloudfirst-systems', 'Cloud-based networking services'),
            ('DataStream Ltd', 'datastream-ltd', 'Data center and connectivity solutions'),
        ]
        
        managers = [u for u in users if u.role == User.MANAGER]
        
        for i, (name, slug, desc) in enumerate(org_data):
            org, created = Organisation.objects.get_or_create(
                slug=slug,
                defaults={
                    'name': name,
                    'description': desc,
                    'created_by': managers[i % len(managers)],
                    'is_active': True,
                }
            )
            orgs.append(org)
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(orgs)} organisations'))
        return orgs

    def create_memberships(self, users, orgs):
        """Assign users to organisations with appropriate roles"""
        self.stdout.write('Creating memberships...')
        count = 0
        
        managers = [u for u in users if u.role == User.MANAGER]
        technicians = [u for u in users if u.role == User.TECHNICIAN]
        customers = [u for u in users if u.role == User.CUSTOMER]
        
        # Assign managers to orgs
        for i, manager in enumerate(managers):
            org = orgs[i % len(orgs)]
            Membership.objects.get_or_create(
                organisation=org,
                user=manager,
                defaults={'role': 'manager'}
            )
            count += 1
        
        # Assign technicians to orgs (some to multiple orgs)
        for tech in technicians:
            num_orgs = random.randint(1, 2)
            for org in random.sample(orgs, num_orgs):
                Membership.objects.get_or_create(
                    organisation=org,
                    user=tech,
                    defaults={'role': 'technician'}
                )
                count += 1
        
        # Assign customers to orgs
        for customer in customers:
            org = random.choice(orgs)
            Membership.objects.get_or_create(
                organisation=org,
                user=customer,
                defaults={'role': 'customer'}
            )
            count += 1
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {count} memberships'))

    def create_device_types(self):
        """Create common device types"""
        self.stdout.write('Creating device types...')
        types_data = [
            ('Router', 'Network routing device'),
            ('Switch', 'Network switching device'),
            ('Firewall', 'Security firewall device'),
            ('Access Point', 'Wireless access point'),
            ('Load Balancer', 'Traffic load balancer'),
            ('Server', 'Application or database server'),
        ]
        
        types = []
        for name, desc in types_data:
            dt, _ = DeviceType.objects.get_or_create(
                name=name,
                defaults={'description': desc}
            )
            types.append(dt)
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(types)} device types'))
        return types

    def create_metrics(self):
        """Create metric types"""
        self.stdout.write('Creating metrics...')
        metrics_data = [
            ('Bandwidth', 'Mbps', 'Network bandwidth usage'),
            ('Latency', 'ms', 'Network latency'),
            ('Packet Loss', '%', 'Percentage of lost packets'),
            ('CPU Usage', '%', 'CPU utilization percentage'),
            ('Memory Usage', '%', 'Memory utilization percentage'),
            ('Disk Usage', '%', 'Disk space utilization'),
            ('Temperature', '°C', 'Device temperature'),
            ('Uptime', 'hours', 'Device uptime'),
        ]
        
        metrics = []
        for name, unit, desc in metrics_data:
            m, _ = Metric.objects.get_or_create(
                name=name,
                defaults={'unit': unit, 'description': desc}
            )
            metrics.append(m)
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(metrics)} metrics'))
        return metrics

    def create_devices(self, device_types, orgs):
        """Create devices across organisations"""
        self.stdout.write('Creating devices...')
        devices = []
        
        locations = [
            'New York Data Center', 'London Office', 'Tokyo Branch',
            'San Francisco HQ', 'Berlin Office', 'Singapore Hub',
            'Sydney Data Center', 'Toronto Office', 'Mumbai Branch',
        ]
        
        statuses = ['online', 'online', 'online', 'offline', 'unreachable']
        
        # Create 50 devices
        for i in range(50):
            org = random.choice(orgs)
            device_type = random.choice(device_types)
            status = random.choice(statuses)
            
            # Generate unique IP
            ip = f"192.168.{random.randint(1, 254)}.{random.randint(1, 254)}"
            
            # Check if IP exists, regenerate if needed
            while Device.objects.filter(ip_address=ip).exists():
                ip = f"192.168.{random.randint(1, 254)}.{random.randint(1, 254)}"
            
            device = Device.objects.create(
                name=f"{device_type.name}-{i+1:03d}",
                device_type=device_type,
                ip_address=ip,
                location=random.choice(locations),
                status=status,
                last_seen=timezone.now() - timedelta(minutes=random.randint(0, 120)) if status == 'online' else None,
                snmp_community='public',
                organisation=org,
            )
            devices.append(device)
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(devices)} devices'))
        return devices

    def create_metric_thresholds(self, devices, metrics):
        """Create thresholds for devices"""
        self.stdout.write('Creating metric thresholds...')
        count = 0
        
        threshold_configs = {
            'Bandwidth': (80, 95),
            'Latency': (100, 200),
            'Packet Loss': (1, 5),
            'CPU Usage': (70, 90),
            'Memory Usage': (75, 90),
            'Disk Usage': (80, 95),
            'Temperature': (60, 75),
        }
        
        for device in devices:
            for metric in metrics:
                if metric.name in threshold_configs:
                    warn, crit = threshold_configs[metric.name]
                    MetricThreshold.objects.get_or_create(
                        device=device,
                        metric=metric,
                        defaults={
                            'warning_threshold': warn,
                            'critical_threshold': crit,
                            'is_active': True,
                        }
                    )
                    count += 1
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {count} metric thresholds'))

    def create_metric_readings(self, devices, metrics):
        """Create historical metric readings"""
        self.stdout.write('Creating metric readings (this may take a moment)...')
        readings = []
        
        # Create readings for the last 7 days
        now = timezone.now()
        
        for device in devices:
            # Only create readings for online devices
            if device.status != 'online':
                continue
            
            for metric in metrics:
                # Create readings every 5 minutes for the last 24 hours
                for i in range(288):  # 24 hours * 12 readings per hour
                    timestamp = now - timedelta(minutes=i * 5)
                    
                    # Generate realistic values based on metric type
                    if metric.name == 'Bandwidth':
                        value = random.uniform(10, 100)
                    elif metric.name == 'Latency':
                        value = random.uniform(5, 150)
                    elif metric.name == 'Packet Loss':
                        value = random.uniform(0, 3)
                    elif metric.name == 'CPU Usage':
                        value = random.uniform(20, 85)
                    elif metric.name == 'Memory Usage':
                        value = random.uniform(30, 80)
                    elif metric.name == 'Disk Usage':
                        value = random.uniform(40, 90)
                    elif metric.name == 'Temperature':
                        value = random.uniform(35, 70)
                    elif metric.name == 'Uptime':
                        value = random.uniform(1, 720)
                    else:
                        value = random.uniform(0, 100)
                    
                    readings.append(MetricReading(
                        device=device,
                        metric=metric,
                        value=value,
                        timestamp=timestamp,
                    ))
        
        # Bulk create for performance
        MetricReading.objects.bulk_create(readings, batch_size=1000)
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(readings)} metric readings'))

    def create_predictions(self, devices, metrics):
        """Create metric predictions"""
        self.stdout.write('Creating predictions...')
        count = 0
        
        risk_levels = ['low', 'low', 'low', 'medium', 'medium', 'high', 'critical']
        
        for device in devices[:20]:  # Only for first 20 devices
            if device.status != 'online':
                continue
            
            for metric in random.sample(list(metrics), 3):  # 3 random metrics per device
                MetricPrediction.objects.get_or_create(
                    device=device,
                    metric=metric,
                    defaults={
                        'predicted_value': random.uniform(50, 95),
                        'slope_per_min': random.uniform(-0.5, 2.0),
                        'risk_level': random.choice(risk_levels),
                        'horizon_minutes': 60,
                    }
                )
                count += 1
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {count} predictions'))

    def create_alert_rules(self, devices, metrics):
        """Create alert rules"""
        self.stdout.write('Creating alert rules...')
        rules = []
        
        rule_templates = [
            ('High CPU Usage', 'CPU Usage', 'gt', 80, 'high'),
            ('Critical Memory', 'Memory Usage', 'gt', 90, 'critical'),
            ('High Latency', 'Latency', 'gt', 150, 'medium'),
            ('Packet Loss Alert', 'Packet Loss', 'gt', 2, 'high'),
            ('Bandwidth Saturation', 'Bandwidth', 'gt', 95, 'critical'),
        ]
        
        for device in random.sample(list(devices), 20):
            for name, metric_name, condition, threshold, severity in rule_templates:
                metric = Metric.objects.get(name=metric_name)
                rule = AlertRule.objects.create(
                    name=f"{name} - {device.name}",
                    description=f"Alert when {metric_name} exceeds threshold",
                    device=device,
                    metric=metric,
                    condition=condition,
                    threshold=threshold,
                    severity=severity,
                    enabled=True,
                )
                rules.append(rule)
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(rules)} alert rules'))
        return rules

    def create_alerts(self, alert_rules, devices, users):
        """Create alert instances spread across the last 7 days"""
        self.stdout.write('Creating alerts...')
        alerts = []
        
        statuses = ['new', 'new', 'acknowledged', 'resolved']
        technicians = [u for u in users if u.role == User.TECHNICIAN]
        
        # Create 100 alerts spread across 7 days
        for rule in random.sample(list(alert_rules), min(100, len(alert_rules))):
            status = random.choice(statuses)
            
            # Spread alerts across last 7 days (0-168 hours)
            hours_ago = random.randint(1, 168)
            
            alert = Alert.objects.create(
                rule=rule,
                device=rule.device,
                severity=rule.severity,
                status=status,
                message=f"{rule.metric.name} exceeded threshold: {rule.threshold}{rule.metric.unit}",
                triggered_at=timezone.now() - timedelta(hours=hours_ago),
            )
            
            if status in ['acknowledged', 'resolved']:
                alert.acknowledged_at = alert.triggered_at + timedelta(minutes=random.randint(5, 60))
                alert.acknowledged_by = random.choice(technicians) if technicians else None
            
            if status == 'resolved':
                alert.resolved_at = alert.acknowledged_at + timedelta(minutes=random.randint(10, 120))
            
            alert.save()
            alerts.append(alert)
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {len(alerts)} alerts'))

    def create_notification_channels(self, users):
        """Create notification channels for users"""
        self.stdout.write('Creating notification channels...')
        count = 0
        
        for user in users:
            if user.role in [User.TECHNICIAN, User.MANAGER]:
                # Email channel
                NotificationChannel.objects.get_or_create(
                    user=user,
                    channel_type='email',
                    address=user.email,
                    defaults={'is_active': True, 'verified': True}
                )
                count += 1
                
                # SMS channel for some users
                if random.random() > 0.5 and user.phone:
                    NotificationChannel.objects.get_or_create(
                        user=user,
                        channel_type='sms',
                        address=user.phone,
                        defaults={'is_active': True, 'verified': True}
                    )
                    count += 1
        
        self.stdout.write(self.style.SUCCESS(f'✓ Created {count} notification channels'))

    def print_summary(self, users, orgs, devices):
        """Print summary of created data"""
        self.stdout.write('\n' + '='*60)
        self.stdout.write(self.style.SUCCESS('SEEDING SUMMARY'))
        self.stdout.write('='*60)
        
        self.stdout.write(f"\nUsers created:")
        self.stdout.write(f"  - Admins: {len([u for u in users if u.role == User.ADMIN])}")
        self.stdout.write(f"  - Managers: {len([u for u in users if u.role == User.MANAGER])}")
        self.stdout.write(f"  - Technicians: {len([u for u in users if u.role == User.TECHNICIAN])}")
        self.stdout.write(f"  - Customers: {len([u for u in users if u.role == User.CUSTOMER])}")
        
        self.stdout.write(f"\nOrganisations: {len(orgs)}")
        self.stdout.write(f"Devices: {len(devices)}")
        self.stdout.write(f"  - Online: {len([d for d in devices if d.status == 'online'])}")
        self.stdout.write(f"  - Offline: {len([d for d in devices if d.status == 'offline'])}")
        
        self.stdout.write(f"\nMetric Readings: {MetricReading.objects.count()}")
        self.stdout.write(f"Alerts: {Alert.objects.count()}")
        self.stdout.write(f"  - New: {Alert.objects.filter(status='new').count()}")
        self.stdout.write(f"  - Acknowledged: {Alert.objects.filter(status='acknowledged').count()}")
        self.stdout.write(f"  - Resolved: {Alert.objects.filter(status='resolved').count()}")
        
        self.stdout.write('\n' + '='*60)
        self.stdout.write(self.style.SUCCESS('\nLogin credentials (all users):'))
        self.stdout.write('  Username: admin / Password: admin123')
        self.stdout.write('  Username: <any_username> / Password: password123')
        self.stdout.write('='*60 + '\n')
