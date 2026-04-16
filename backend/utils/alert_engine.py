"""Alert Engine — evaluates enabled AlertRules against the latest MetricReadings."""
import logging

logger = logging.getLogger(__name__)

_CONDITION_FNS = {
    'gt':  lambda v, t: v >  t,
    'gte': lambda v, t: v >= t,
    'lt':  lambda v, t: v <  t,
    'lte': lambda v, t: v <= t,
    'eq':  lambda v, t: abs(v - t) < 1e-9,
}


def ensure_default_rules() -> None:
    """Seed default alert rules for common network saturation problems."""
    from alerts.models import AlertRule
    from metrics.models import Metric

    metrics = {
        'latency_ms':       ('ms', 'Average RTT in milliseconds'),
        'cpu_usage_pct':    ('%',  'CPU utilization percentage'),
        'memory_usage_pct': ('%',  'Memory utilization percentage'),
        'mac_table_entries':('count', 'MAC address table size'),
        'power_load_pct':   ('%',  'Power/UPS load percentage'),
    }

    metric_objs = {}
    for name, (unit, desc) in metrics.items():
        metric_objs[name], _ = Metric.objects.get_or_create(
            name=name,
            defaults={'unit': unit, 'description': desc},
        )

    defaults = [
        ('High Latency',            'latency_ms',        'gt', 150.0, 'high',
         'RTT above 150ms indicates potential congestion or path issues.'),
        ('Critical Latency',        'latency_ms',        'gt', 300.0, 'critical',
         'RTT above 300ms indicates severe service degradation.'),
        ('High CPU Usage',          'cpu_usage_pct',     'gt', 80.0,  'high',
         'CPU usage above 80% risks packet drops and control plane delays.'),
        ('Critical CPU Usage',      'cpu_usage_pct',     'gt', 90.0,  'critical',
         'CPU usage above 90% risks device instability.'),
        ('High Memory Usage',       'memory_usage_pct',  'gt', 80.0,  'high',
         'Memory usage above 80% risks process starvation.'),
        ('Critical Memory Usage',   'memory_usage_pct',  'gt', 90.0,  'critical',
         'Memory usage above 90% risks crashes or reloads.'),
        ('MAC Table Saturation',    'mac_table_entries', 'gt', 8000.0, 'high',
         'Large MAC table may indicate loops or unauthorized switches.'),
        ('Critical MAC Saturation', 'mac_table_entries', 'gt', 12000.0, 'critical',
         'MAC table near capacity can cause flooding and client drops.'),
        ('High Power Load',         'power_load_pct',    'gt', 80.0,  'high',
         'Power/UPS load above 80% reduces headroom.'),
        ('Critical Power Load',     'power_load_pct',    'gt', 90.0,  'critical',
         'Power/UPS load above 90% risks brownouts.'),
    ]

    for name, metric_key, condition, threshold, severity, desc in defaults:
        AlertRule.objects.get_or_create(
            name=name,
            defaults={
                'description': desc,
                'metric': metric_objs[metric_key],
                'condition': condition,
                'threshold': threshold,
                'severity': severity,
                'enabled': True,
            },
        )


def sync_threshold_rules() -> None:
    """Sync per-device MetricThreshold entries into alert rules."""
    from alerts.models import AlertRule
    from metrics.models import MetricThreshold

    thresholds = (
        MetricThreshold.objects
        .filter(is_active=True)
        .select_related('device', 'metric')
    )

    for t in thresholds:
        if t.device is None or t.metric is None:
            continue

        def _upsert(level: str, threshold_value: float, severity: str) -> None:
            name = f'Override: {t.device.name} {t.metric.name} ({level})'
            rule = AlertRule.objects.filter(
                device=t.device,
                metric=t.metric,
                condition='gt',
                severity=severity,
            ).first()
            if rule:
                rule.name = name
                rule.description = 'Per-device metric threshold override.'
                rule.threshold = threshold_value
                rule.enabled = True
                rule.save(update_fields=['name', 'description', 'threshold', 'enabled', 'updated_at'])
            else:
                AlertRule.objects.create(
                    name=name,
                    description='Per-device metric threshold override.',
                    device=t.device,
                    metric=t.metric,
                    condition='gt',
                    threshold=threshold_value,
                    severity=severity,
                    enabled=True,
                )

        if t.warning_threshold is not None:
            _upsert('warning', t.warning_threshold, 'high')
        if t.critical_threshold is not None:
            _upsert('critical', t.critical_threshold, 'critical')


def evaluate_rules() -> int:
    """
    Iterate every enabled AlertRule, fetch the latest MetricReading for its
    device+metric, and create a new Alert when the condition is satisfied.

    Deduplicates: skips rules that already have an open (new / acknowledged) alert.
    Returns the number of new Alert objects created.
    """
    from alerts.models import AlertRule, Alert
    from metrics.models import MetricReading

    rules = (
        AlertRule.objects
        .filter(enabled=True)
        .select_related('device', 'metric')
    )

    created = 0
    for rule in rules:
        check = _CONDITION_FNS.get(rule.condition)
        if check is None or rule.metric is None:
            continue

        target_devices = [rule.device] if rule.device else []
        if rule.device is None:
            device_ids = (
                MetricReading.objects
                .filter(metric=rule.metric)
                .values_list('device_id', flat=True)
                .distinct()
            )
            from devices.models import Device
            target_devices = list(Device.objects.filter(id__in=device_ids))

        for device in target_devices:
            if device is None:
                continue
            reading = (
                MetricReading.objects
                .filter(metric=rule.metric, device=device)
                .order_by('-timestamp')
                .first()
            )
            if reading is None or not check(reading.value, rule.threshold):
                continue

            if Alert.objects.filter(
                rule=rule,
                device=device,
                status__in=('new', 'acknowledged')
            ).exists():
                continue

            Alert.objects.create(
                rule=rule,
                device=device,
                severity=rule.severity,
                status='new',
                message=(
                    f'{rule.metric.name} = {reading.value:.2f} '
                    f'(rule: {rule.condition} {rule.threshold})'
                ),
            )
            created += 1
            logger.info(
                'Alert fired: rule="%s" device="%s" value=%s',
                rule.name, device.name, reading.value,
            )

    return created
