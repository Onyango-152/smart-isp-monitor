"""SNMP Poller — queries network devices using SNMP v2c and stores metric readings."""
import asyncio
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Standard MIB-2 OIDs most ISP equipment supports
_OIDS = {
    'uptime_seconds':   '1.3.6.1.2.1.1.3.0',          # sysUpTimeInstance (hundredths of a second)
    'interface_errors': '1.3.6.1.2.1.2.2.1.14.1',     # ifInErrors on interface 1
    'hr_processor_load': '1.3.6.1.2.1.25.3.3.1.2',    # hrProcessorLoad (per CPU)
    'hr_storage_descr':  '1.3.6.1.2.1.25.2.3.1.3',    # hrStorageDescr
    'hr_storage_size':   '1.3.6.1.2.1.25.2.3.1.5',    # hrStorageSize
    'hr_storage_used':   '1.3.6.1.2.1.25.2.3.1.6',    # hrStorageUsed
    'mac_table_entry':   '1.3.6.1.2.1.17.4.3.1.1',    # dot1dTpFdbAddress
    'ups_output_load':   '1.3.6.1.2.1.33.1.4.4.1.5',  # upsOutputPercentLoad (UPS-MIB)
    'ping_avg_rtt':      '1.3.6.1.2.1.80.1.3.1.1.4',  # pingResultsAverageRTT (DISMAN-PING-MIB)
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


async def _snmp_walk(host: str, community: str, oid: str, max_rows: int = 200):
    """Return a list of (oid, value) tuples for a subtree walk."""
    try:
        from pysnmp.hlapi.v3arch.asyncio import (
            CommunityData, ContextData, ObjectIdentity, ObjectType,
            SnmpEngine, UdpTransportTarget, nextCmd,
        )
        engine = SnmpEngine()
        results = []
        async for (error_indication, error_status, _, var_binds) in nextCmd(
            engine,
            CommunityData(community, mpModel=1),
            await UdpTransportTarget.create((host, 161), timeout=5, retries=1),
            ContextData(),
            ObjectType(ObjectIdentity(oid)),
            lexicographicMode=False,
        ):
            if error_indication or error_status:
                break
            for name, val in var_binds:
                if not str(name).startswith(oid):
                    engine.closeDispatcher()
                    return results
                results.append((str(name), val))
                if len(results) >= max_rows:
                    engine.closeDispatcher()
                    return results
        engine.closeDispatcher()
        return results
    except Exception as exc:
        logger.debug('SNMP WALK %s@%s failed: %s', oid, host, exc)
        return []


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

        cpu_rows = await _snmp_walk(host, community, _OIDS['hr_processor_load'])
        if cpu_rows:
            values = []
            for _, val in cpu_rows:
                try:
                    values.append(float(val))
                except (TypeError, ValueError):
                    continue
            if values:
                results['cpu_usage_pct'] = sum(values) / len(values)

        descr_rows = await _snmp_walk(host, community, _OIDS['hr_storage_descr'])
        mem_index = None
        for oid, val in descr_rows:
            desc = str(val).lower()
            if 'physical memory' in desc or desc == 'ram':
                try:
                    mem_index = int(oid.split('.')[-1])
                    break
                except (TypeError, ValueError):
                    continue
        if mem_index is not None:
            size = await _snmp_get_one(host, community, f"{_OIDS['hr_storage_size']}.{mem_index}")
            used = await _snmp_get_one(host, community, f"{_OIDS['hr_storage_used']}.{mem_index}")
            if size and used:
                results['memory_usage_pct'] = (used / size) * 100.0

        mac_rows = await _snmp_walk(host, community, _OIDS['mac_table_entry'], max_rows=2000)
        if mac_rows:
            results['mac_table_entries'] = float(len(mac_rows))

        power_rows = await _snmp_walk(host, community, _OIDS['ups_output_load'])
        if power_rows:
            values = []
            for _, val in power_rows:
                try:
                    values.append(float(val))
                except (TypeError, ValueError):
                    continue
            if values:
                results['power_load_pct'] = sum(values) / len(values)

        rtt_rows = await _snmp_walk(host, community, _OIDS['ping_avg_rtt'])
        if rtt_rows:
            try:
                results['latency_ms'] = float(rtt_rows[0][1])
            except (TypeError, ValueError):
                pass

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
        'cpu_usage_pct':    '%',
        'memory_usage_pct': '%',
        'mac_table_entries':'count',
        'power_load_pct':   '%',
    }
    for metric_name, value in results.items():
        metric, _ = Metric.objects.get_or_create(
            name=metric_name,
            defaults={'unit': _UNITS.get(metric_name, '')},
        )
        MetricReading.objects.create(device=device, metric=metric, value=value)
