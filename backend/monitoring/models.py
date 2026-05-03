from django.db import models
from devices.models import Device
from django.contrib.auth import get_user_model

User = get_user_model()

class MonitoringTask(models.Model):
    """
    Defines scheduled monitoring tasks that run periodically.
    These tasks poll devices and collect metrics at defined intervals.
    
    Fields:
    - name: Descriptive name for the task
    - device: Device to monitor (None = all devices)
    - task_type: What data is being collected (snmp, ping, http, etc.)
    - interval: How often to run the task (in seconds)
    - enabled: Whether the task is active
    - last_run: When the task last executed
    """
    TASK_TYPE_CHOICES = [
        ('snmp', 'SNMP Polling'),
        ('ping', 'ICMP Ping'),
        ('http', 'HTTP Check'),
        ('tcp', 'TCP Connection'),
        ('dns', 'DNS Lookup'),
    ]
    
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    device = models.ForeignKey(Device, on_delete=models.CASCADE, null=True, blank=True, related_name='monitoring_tasks')
    assigned_to = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_tasks')
    task_type = models.CharField(max_length=50, choices=TASK_TYPE_CHOICES)
    interval = models.IntegerField(help_text="Interval in seconds")  # e.g., 300 for 5 minutes
    timeout = models.IntegerField(default=5, help_text="Timeout in seconds")
    enabled = models.BooleanField(default=True)
    last_run = models.DateTimeField(null=True, blank=True)
    last_status = models.CharField(max_length=20, default='pending')  # success, failed, pending
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['name']
        verbose_name = 'Monitoring Task'
        verbose_name_plural = 'Monitoring Tasks'
    
    def __str__(self):
        device_str = self.device.name if self.device else "All Devices"
        return f"{self.name} - {self.get_task_type_display()} on {device_str}"


class MonitoringReport(models.Model):
    """
    Stores the results/logs of monitoring task executions.
    
    Fields:
    - task: The MonitoringTask that generated this report
    - executed_at: When the task was executed
    - status: Whether execution was successful
    - duration: How long the task took (in ms)
    - details: Additional status information or error messages
    - metrics_collected: Number of metrics collected in this run
    """
    STATUS_CHOICES = [
        ('success', 'Success'),
        ('partial', 'Partial Success'),
        ('failed', 'Failed'),
        ('timeout', 'Timeout'),
    ]
    
    task = models.ForeignKey(MonitoringTask, on_delete=models.CASCADE, related_name='reports')
    executed_at = models.DateTimeField(auto_now_add=True, db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES)
    duration_ms = models.IntegerField(null=True, blank=True)  # Execution time in milliseconds
    details = models.TextField(blank=True, null=True)  # Error messages or additional info
    metrics_collected = models.IntegerField(default=0)
    
    class Meta:
        ordering = ['-executed_at']
        indexes = [
            models.Index(fields=['task', '-executed_at']),
        ]
        verbose_name = 'Monitoring Report'
        verbose_name_plural = 'Monitoring Reports'
    
    def __str__(self):
        return f"{self.task.name} - {self.get_status_display()} @ {self.executed_at}"


class SystemHealth(models.Model):
    """
    Tracks overall system health statistics and summary metrics.
    Provides a quick view of the monitoring infrastructure status.
    
    Fields:
    - healthy_devices: Number of devices currently online
    - total_devices: Total number of devices being monitored
    - total_alerts: Current active alerts count
    - last_update: When these statistics were last updated
    """
    healthy_devices = models.IntegerField(default=0)
    total_devices = models.IntegerField(default=0)
    total_alerts = models.IntegerField(default=0)
    failed_tasks = models.IntegerField(default=0)
    total_tasks = models.IntegerField(default=0)
    uptime_percentage = models.FloatField(default=100.0)  # System uptime %
    last_update = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'System Health'
        verbose_name_plural = 'System Health'
    
    def __str__(self):
        return f"System Health - {self.healthy_devices}/{self.total_devices} devices online"
