from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()

# Avoid circular import — organisations imports nothing from devices
def _org_model():
    from organisations.models import Organisation
    return Organisation

class DeviceType(models.Model):
    """
    Enumeration of device types that can be monitored.
    Examples: Router, Switch, Firewall, Access Point, etc.
    """
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True, null=True)
    
    def __str__(self):
        return self.name

    class Meta:
        verbose_name = 'Device Type'
        verbose_name_plural = 'Device Types'


class Device(models.Model):
    """
    Represents an ISP device (router, switch, firewall, etc.) being monitored.
    
    Fields:
    - name: Human-readable device name
    - device_type: Type of device (Router, Switch, etc.)
    - ip_address: IPv4 or IPv6 address for monitoring
    - location: Physical location of the device
    - status: Current operational status
    - last_seen: Last time device was successfully polled
    - snmp_community: SNMP community string for device polling
    - assigned_to: User responsible for this device
    """
    STATUS_CHOICES = [
        ('online', 'Online'),
        ('offline', 'Offline'),
        ('unreachable', 'Unreachable'),
        ('maintenance', 'Under Maintenance'),
    ]
    
    name = models.CharField(max_length=255)
    device_type = models.ForeignKey(DeviceType, on_delete=models.SET_NULL, null=True)
    ip_address = models.GenericIPAddressField(unique=True)
    location = models.CharField(max_length=255, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='offline')
    last_seen = models.DateTimeField(null=True, blank=True)
    snmp_community = models.CharField(max_length=255, blank=True, null=True)
    
    # ── Workspace scoping ────────────────────────────────────────────────
    organisation = models.ForeignKey(
        'organisations.Organisation',
        on_delete=models.CASCADE,
        related_name='devices',
        null=True,  # Temporarily nullable for migration
        blank=True,
    )
    
    # Legacy field — kept for backward compat, but org membership is primary
    assigned_to = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['name']
        verbose_name = 'Device'
        verbose_name_plural = 'Devices'
    
    def __str__(self):
        return f"{self.name} ({self.ip_address})"
