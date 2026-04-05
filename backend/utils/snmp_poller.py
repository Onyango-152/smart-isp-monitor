"""SNMP Poller — queries network devices using SNMP v2c and stores metric readings."""
import asyncio
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Standard MIB-2 OIDs most ISP equipment supports
_OIDS = {
    'uptime_seconds':   '1.3.6.1.2.1.1.3.0',        # sysUpTimeInstance (hundredths of a second)
    'interface_errors': '1.3.6.1.2.1.2.2.1.14.1',   # ifInErrors on interface 1
}

async def _snmp_get_one(host: str, community: str, oid: str) -> Optional[float]:
    """Fire a single SNMP GET for `oid`.  Returns float or None on any failure."""
    try:
        from pysnmp.hlapi.v3arch.asyncio import (
            CommunityData, ContextData, ObjectIdentity, ObjectType,
            SnmpEngine, UdpTransportTarget, getCmd,
        )
        engine = SnmpEngine()
        error_indication, error_status, _, var_binds = await getCmd(
            engine,
            CommunityData(community, mpModel=1),
            await UdpTransportTarget.create((host, 161), timeout=5, retries=1),
            ContextData(),
            ObjectType(ObjectIdentity(oid)),
        )
        engine.closeDispatcher()
        if error_indication or error_status:
            return None
        for _, val in var_binds:
            try:
                return float(val)
            except (TypeError, ValueError):
                return None
    except Exception as exc:
        logger.debug('SNMP GET %s@%s failed: %s', oid, host, exc)
    return None


def poll_device(device) -> dict:
    """
    Poll `device` via SNMP and return {metric_name: float_value}.
    Runs IO inside a fresh event loop so it works from sync + Celery contexts.
    """
    community = device.snmp_community or 'public'
    host      = str(device.ip_address)
    results: dict = {}

    async def _collect():
        uptime_raw = await _snmp_get_one(host, community, _OIDS['uptime_seconds'])
        if uptime_raw is not None:
            results['uptime_seconds'] = uptime_raw / 100.0  # hundredths → seconds

        in_errors = await _snmp_get_one(host, community, _OIDS['interface_errors'])
        if in_errors is not None:
            results['interface_errors'] = in_errors

    try:
        asyncio.run(_collect())
    except RuntimeError:
        # Already inside an event loop (e.g. tests) — run in new thread
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            pool.submit(asyncio.run, _collect()).result(timeout=15)
    except Exception as exc:
        logger.warning('SNMP poll failed for %s: %s', host, exc)

    return results


def save_poll_results(device, results: dict) -> None:
    """Persist `results` from `poll_device` as MetricReading rows."""
    from metrics.models import Metric, MetricReading

    _UNITS = {
        'uptime_seconds':   's',
        'interface_errors': 'count',
        'latency_ms':       'ms',
        'packet_loss_pct':  '%',
    }
    for metric_name, value in results.items():
        metric, _ = Metric.objects.get_or_create(
            name=metric_name,
            defaults={'unit': _UNITS.get(metric_name, '')},
        )
        MetricReading.objects.create(device=device, metric=metric, value=value)
