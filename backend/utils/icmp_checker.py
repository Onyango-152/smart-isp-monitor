"""ICMP Checker — pings a host and returns latency / packet-loss stats."""
import asyncio
import logging
import platform
import subprocess
import re
from typing import Optional

logger = logging.getLogger(__name__)


def _parse_ping_output(output: str) -> dict:
    """
    Parse the stdout of a system ping command into a dict with:
      latency_ms      — average round-trip time in ms (float or None)
      packet_loss_pct — percentage of lost packets (float)
    Works on both Linux/macOS and Windows ping output.
    """
    result = {'latency_ms': None, 'packet_loss_pct': 100.0}

    # Packet loss — matches "20% packet loss" (Linux/macOS) or "20% loss" (Windows)
    loss_match = re.search(r'(\d+(?:\.\d+)?)\s*%\s*(?:packet\s+)?loss', output, re.IGNORECASE)
    if loss_match:
        result['packet_loss_pct'] = float(loss_match.group(1))

    # Average latency — Linux/macOS: "rtt min/avg/max/mdev = 1.2/3.4/5.6/0.8 ms"
    avg_match = re.search(
        r'(?:rtt|round-trip)[^=]*=\s*[\d.]+/([\d.]+)/', output, re.IGNORECASE
    )
    if avg_match:
        result['latency_ms'] = float(avg_match.group(1))
        return result

    # Windows: "Average = 3ms" or "Average = 3 ms"
    win_match = re.search(r'Average\s*=\s*([\d.]+)\s*ms', output, re.IGNORECASE)
    if win_match:
        result['latency_ms'] = float(win_match.group(1))

    return result


def ping_host(host: str, count: int = 4, timeout: int = 5) -> dict:
    """
    Ping `host` using the OS ping command.

    Returns:
        {
            'reachable':       bool,
            'latency_ms':      float | None,   # avg RTT
            'packet_loss_pct': float,           # 0–100
        }
    """
    is_windows = platform.system().lower() == 'windows'

    if is_windows:
        cmd = ['ping', '-n', str(count), '-w', str(timeout * 1000), host]
    else:
        cmd = ['ping', '-c', str(count), '-W', str(timeout), host]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout * count + 5,
        )
        output = proc.stdout + proc.stderr
        stats  = _parse_ping_output(output)
        stats['reachable'] = proc.returncode == 0
        return stats
    except subprocess.TimeoutExpired:
        logger.warning('ping timed out for %s', host)
        return {'reachable': False, 'latency_ms': None, 'packet_loss_pct': 100.0}
    except FileNotFoundError:
        logger.warning('ping command not found on this system')
        return {'reachable': False, 'latency_ms': None, 'packet_loss_pct': 100.0}
    except Exception as exc:
        logger.warning('ping failed for %s: %s', host, exc)
        return {'reachable': False, 'latency_ms': None, 'packet_loss_pct': 100.0}


def save_ping_results(device, results: dict) -> None:
    """Persist ping results as MetricReading rows."""
    from metrics.models import Metric, MetricReading

    _UNITS = {
        'latency_ms':      'ms',
        'packet_loss_pct': '%',
    }
    for metric_name in ('latency_ms', 'packet_loss_pct'):
        value = results.get(metric_name)
        if value is None:
            continue
        metric, _ = Metric.objects.get_or_create(
            name=metric_name,
            defaults={'unit': _UNITS[metric_name]},
        )
        MetricReading.objects.create(device=device, metric=metric, value=value)
