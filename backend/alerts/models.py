from django.db import models
from devices.models import Device
from metrics.models import Metric
from django.contrib.auth import get_user_model

User = get_user_model()

class AlertRule(models.Model):
    """
    Defines the configuration for when and how alerts should be triggered.
    Combines device, metric, thresholds, and notification settings.
    
    Fields:
    - name: Descriptive name for the rule
    - device: Device this rule applies to (None = applies to all)
    - metric: Metric that triggers this rule (None = applies to all metrics)
    - condition: Type of condition (gt=greater than, lt=less than, etc.)
    - threshold: The value that triggers the alert
    - severity: How critical the alert is
    - enabled: Whether this rule is currently active
    """
    CONDITION_CHOICES = [
        ('gt', 'Greater Than'),
        ('lt', 'Less Than'),
        ('eq', 'Equal To'),
        ('gte', 'Greater Than Or Equal'),
        ('lte', 'Less Than Or Equal'),
    ]
    
    SEVERITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ]
    
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    device = models.ForeignKey(Device, on_delete=models.CASCADE, null=True, blank=True, related_name='alert_rules')
    metric = models.ForeignKey(Metric, on_delete=models.CASCADE, null=True, blank=True)
    condition = models.CharField(max_length=10, choices=CONDITION_CHOICES)
    threshold = models.FloatField()
    severity = models.CharField(max_length=20, choices=SEVERITY_CHOICES)
    enabled = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Alert Rule'
        verbose_name_plural = 'Alert Rules'
    
    def __str__(self):
        device_name = self.device.name if self.device else "All Devices"
        metric_name = self.metric.name if self.metric else "All Metrics"
        return f"{self.name} ({device_name} - {metric_name})"


class Alert(models.Model):
    """
    Records individual alert instances when conditions are met.
    This is the alert history/log showing when problems occurred.
    
    Fields:
    - rule: The AlertRule that triggered this alert
    - device: Device where the problem occurred
    - severity: How critical this alert is
    - status: Current state of the alert (new, acknowledged, resolved)
    - message: Human-readable description of the problem
    - triggered_at: When the alert condition was first detected
    - acknowledged_at: When someone acknowledged the alert
    - resolved_at: When the problem was resolved
    """
    STATUS_CHOICES = [
        ('new', 'New'),
        ('acknowledged', 'Acknowledged'),
        ('resolved', 'Resolved'),
        ('false_positive', 'False Positive'),
    ]
    
    rule = models.ForeignKey(AlertRule, on_delete=models.SET_NULL, null=True, related_name='alerts')
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name='alerts')
    severity = models.CharField(max_length=20, choices=AlertRule.SEVERITY_CHOICES)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='new')
    message = models.TextField()
    triggered_at = models.DateTimeField(auto_now_add=True)
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    acknowledged_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='acknowledged_alerts')
    customer_reported = models.BooleanField(default=False)
    reported_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='customer_reported_alerts')
    reported_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        ordering = ['-triggered_at']
        indexes = [
            models.Index(fields=['status', '-triggered_at']),
            models.Index(fields=['device', '-triggered_at']),
        ]
        verbose_name = 'Alert'
        verbose_name_plural = 'Alerts'
    
    def __str__(self):
        return f"[{self.severity.upper()}] {self.device.name}: {self.message}"


class NotificationChannel(models.Model):
    """
    Defines how alerts should be delivered to users.
    Supports email, SMS, webhook, etc.
    
    Fields:
    - channel_type: How alert is sent (email, sms, webhook, etc.)
    - address: Where to send (email address, phone number, webhook URL, etc.)
    - is_active: Whether this channel is currently active
    """
    CHANNEL_CHOICES = [
        ('email', 'Email'),
        ('sms', 'SMS'),
        ('webhook', 'Webhook'),
        ('slack', 'Slack'),
        ('telegram', 'Telegram'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notification_channels')
    channel_type = models.CharField(max_length=20, choices=CHANNEL_CHOICES)
    address = models.CharField(max_length=255)  # Email, phone, webhook URL, etc.
    is_active = models.BooleanField(default=True)
    verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ('user', 'channel_type', 'address')
        verbose_name = 'Notification Channel'
        verbose_name_plural = 'Notification Channels'
    
    def __str__(self):
        return f"{self.user.username} - {self.channel_type}: {self.address}"
