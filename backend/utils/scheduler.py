"""Task Scheduler — runs periodic SNMP polling + alert evaluation via APScheduler."""
import logging

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from django.utils import timezone

logger = logging.getLogger(__name__)
_scheduler: BackgroundScheduler | None = None


def _snmp_cycle() -> None:
    """Poll all SNMP-enabled devices and evaluate alert rules."""
    from devices.models import Device
    from utils.snmp_poller import poll_device, save_poll_results
    from utils.alert_engine import evaluate_rules

    devices = (
        Device.objects
        .filter(snmp_community__isnull=False)
        .exclude(snmp_community='')
        .exclude(status='maintenance')
    )
    for device in devices:
        try:
            results = poll_device(device)
            if results:
                save_poll_results(device, results)
                # Update last_seen timestamp
                device.last_seen = timezone.now()
                device.save(update_fields=['last_seen'])
                logger.debug('Polled %s: %s', device.name, results)
        except Exception as exc:
            logger.warning('Poll failed for %s: %s', device.name, exc)

    try:
        new_alerts = evaluate_rules()
        if new_alerts:
            logger.info('%d new alert(s) raised by alert engine.', new_alerts)
    except Exception as exc:
        logger.warning('Alert engine error: %s', exc)


def start() -> None:
    """Start the background scheduler.  Call once from MonitoringConfig.ready()."""
    global _scheduler
    if _scheduler and _scheduler.running:
        return
    _scheduler = BackgroundScheduler(timezone='UTC')
    _scheduler.add_job(
        _snmp_cycle,
        trigger=IntervalTrigger(seconds=300),   # every 5 minutes
        id='snmp_cycle',
        replace_existing=True,
        next_run_time=timezone.now(),
    )
    _scheduler.start()
    logger.info('Monitoring scheduler started (5-min SNMP cycle).')


def stop() -> None:
    """Stop the scheduler gracefully."""
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        logger.info('Monitoring scheduler stopped.')
