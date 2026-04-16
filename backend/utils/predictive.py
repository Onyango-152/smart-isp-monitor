"""Predictive tracking — rolling averages + slope-based risk estimates."""
from __future__ import annotations

import logging
from datetime import timedelta
from typing import Iterable

from django.utils import timezone

logger = logging.getLogger(__name__)

_TARGET_METRICS = {
	'latency_ms': 150.0,
	'cpu_usage_pct': 80.0,
	'memory_usage_pct': 80.0,
	'mac_table_entries': 8000.0,
	'power_load_pct': 80.0,
}

_CRITICAL_DEFAULTS = {
	'latency_ms': 300.0,
	'cpu_usage_pct': 90.0,
	'memory_usage_pct': 90.0,
	'mac_table_entries': 12000.0,
	'power_load_pct': 90.0,
}


def _linear_slope(points: Iterable[tuple[float, float]]) -> float:
	"""Return slope for (x, y) points using simple linear regression."""
	xs, ys = zip(*points)
	n = len(xs)
	if n < 2:
		return 0.0
	mean_x = sum(xs) / n
	mean_y = sum(ys) / n
	num = sum((x - mean_x) * (y - mean_y) for x, y in points)
	den = sum((x - mean_x) ** 2 for x in xs)
	return num / den if den != 0 else 0.0


def _risk_level(value: float, warn: float | None, crit: float | None) -> str:
	if crit is not None and value >= crit:
		return 'critical'
	if warn is not None and value >= warn:
		return 'high'
	if warn is not None and value >= warn * 0.75:
		return 'medium'
	return 'low'


def compute_predictions(horizon_minutes: int = 60, window_minutes: int = 180) -> int:
	"""
	Compute short-horizon predictions for key metrics per device.
	Returns number of predictions updated.
	"""
	from metrics.models import Metric, MetricReading, MetricThreshold, MetricPrediction
	from devices.models import Device

	cutoff = timezone.now() - timedelta(minutes=window_minutes)
	metrics = Metric.objects.filter(name__in=_TARGET_METRICS.keys())

	updated = 0
	for metric in metrics:
		readings = (
			MetricReading.objects
			.filter(metric=metric, timestamp__gte=cutoff)
			.select_related('device')
			.order_by('device_id', 'timestamp')
		)

		by_device: dict[int, list[MetricReading]] = {}
		for r in readings:
			by_device.setdefault(r.device_id, []).append(r)

		for device_id, series in by_device.items():
			if len(series) < 4:
				continue

			device = series[-1].device
			points = []
			base_time = series[0].timestamp
			for r in series:
				minutes = (r.timestamp - base_time).total_seconds() / 60.0
				points.append((minutes, r.value))

			slope = _linear_slope(points)
			last_value = series[-1].value
			predicted_value = last_value + slope * horizon_minutes

			threshold = MetricThreshold.objects.filter(
				device_id=device_id,
				metric=metric,
				is_active=True,
			).first()
			warn = threshold.warning_threshold if threshold else _TARGET_METRICS.get(metric.name)
			crit = threshold.critical_threshold if threshold else _CRITICAL_DEFAULTS.get(metric.name)

			risk = _risk_level(predicted_value, warn, crit)

			MetricPrediction.objects.update_or_create(
				device=device,
				metric=metric,
				defaults={
					'predicted_value': predicted_value,
					'slope_per_min': slope,
					'risk_level': risk,
					'horizon_minutes': horizon_minutes,
				},
			)
			updated += 1

	logger.info('Updated %d metric predictions.', updated)
	return updated
