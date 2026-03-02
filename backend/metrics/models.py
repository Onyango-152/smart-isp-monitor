from django.db import models
from devices.models import Device
from django.core.validators import MinValueValidator, MaxValueValidator

class Metric(models.Model):
    """
    Represents a network metric or KPI that can be monitored.
    Examples: Bandwidth, Latency, Packet Loss, CPU Usage, Memory Usage, etc.
    """
    name = models.CharField(max_length=100, unique=True)
    unit = models.CharField(max_length=50)  # e.g., Mbps, ms, %, GB
    description = models.TextField(blank=True, null=True)
    
    def __str__(self):
        return f"{self.name} ({self.unit})"
    
    class Meta:
        verbose_name = 'Metric Type'
        verbose_name_plural = 'Metric Types'


class MetricReading(models.Model):
    """
    Stores individual metric readings from devices over time.
    This is time-series data that builds up the historical performance database.
    
    Fields:
    - device: Reference to the Device being measured
    - metric: Type of metric being recorded
    - value: The actual measured value
    - timestamp: When the reading was taken
    """
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='metric_readings')
    metric = models.ForeignKey(Metric, on_delete=models.SET_NULL, null=True)
    value = models.FloatField()
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)
    
    class Meta:
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['device', '-timestamp']),
            models.Index(fields=['metric', '-timestamp']),
        ]
        verbose_name = 'Metric Reading'
        verbose_name_plural = 'Metric Readings'
    
    def __str__(self):
        return f"{self.device.name} - {self.metric.name}: {self.value}{self.metric.unit} @ {self.timestamp}"


class MetricThreshold(models.Model):
    """
    Defines warning and critical thresholds for metrics on specific devices.
    Used to determine when alerts should be triggered.
    
    Fields:
    - device: The device this threshold applies to
    - metric: The metric type being thresholded
    - warning_threshold: Value that triggers a warning alert
    - critical_threshold: Value that triggers a critical alert
    """
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='metric_thresholds')
    metric = models.ForeignKey(Metric, on_delete=models.CASCADE)
    warning_threshold = models.FloatField(null=True, blank=True)
    critical_threshold = models.FloatField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ('device', 'metric')
        verbose_name = 'Metric Threshold'
        verbose_name_plural = 'Metric Thresholds'
    
    def __str__(self):
        return f"{self.device.name} - {self.metric.name}"
