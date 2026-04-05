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
        if rule.device is None or rule.metric is None:
            continue

        reading = (
            MetricReading.objects
            .filter(metric=rule.metric, device=rule.device)
            .order_by('-timestamp')
            .first()
        )
        if reading is None:
            continue

        check = _CONDITION_FNS.get(rule.condition)
        if check is None or not check(reading.value, rule.threshold):
            continue

        # Skip if already an open alert for this rule
        if Alert.objects.filter(rule=rule, status__in=('new', 'acknowledged')).exists():
            continue

        Alert.objects.create(
            rule=rule,
            device=rule.device,
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
            rule.name, rule.device.name, reading.value,
        )

    return created
