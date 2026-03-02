from rest_framework import serializers
from .models import Device, DeviceType


class DeviceTypeSerializer(serializers.ModelSerializer):
    """
    Serializer for Device Types (Router, Switch, Firewall, etc.)
    
    Fields:
    - id: Unique identifier
    - name: Type name
    - description: Description of what this type is
    """
    class Meta:
        model = DeviceType
        fields = ('id', 'name', 'description')


class DeviceSerializer(serializers.ModelSerializer):
    """
    Serializer for Device information including status and configuration.
    
    Fields:
    - id: Unique identifier
    - name: Device name
    - device_type: Type of device
    - ip_address: IP address for monitoring
    - location: Physical location
    - status: Current status (online, offline, etc.)
    - last_seen: When device was last polled
    - assigned_to: User responsible for device
    """
    device_type_name = serializers.CharField(
        source='device_type.name',
        read_only=True
    )
    assigned_to_username = serializers.CharField(
        source='assigned_to.username',
        read_only=True
    )

    class Meta:
        model = Device
        fields = (
            'id', 'name', 'device_type', 'device_type_name',
            'ip_address', 'location', 'status', 'last_seen',
            'snmp_community', 'assigned_to', 'assigned_to_username',
            'created_at', 'updated_at'
        )
        read_only_fields = ('created_at', 'updated_at', 'last_seen')


class DeviceStatusSerializer(serializers.Serializer):
    """
    Serializer for updating device status.
    
    Used when doing a status check/update.
    """
    status = serializers.ChoiceField(
        choices=['online', 'offline', 'unreachable', 'maintenance']
    )
    last_seen = serializers.DateTimeField(required=False)
