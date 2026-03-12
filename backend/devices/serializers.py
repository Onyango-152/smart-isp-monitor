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
    Returns a flat object compatible with the mobile DeviceModel.fromJson.
    """
    # Return device type as a name string (Flutter reads it as String)
    device_type = serializers.SerializerMethodField()
    # Keep a write-only FK field so POST/PUT can still set device_type by id
    device_type_id = serializers.PrimaryKeyRelatedField(
        source='device_type',
        queryset=DeviceType.objects.all(),
        write_only=True,
        required=False,
        allow_null=True,
    )
    assigned_to_username = serializers.CharField(
        source='assigned_to.username',
        read_only=True
    )
    # Fields that exist in the mobile model but not in the Django model
    mac_address  = serializers.SerializerMethodField()
    description  = serializers.SerializerMethodField()
    snmp_enabled = serializers.SerializerMethodField()
    is_active    = serializers.SerializerMethodField()
    # Override snmp_community to always return a string (never null)
    snmp_community = serializers.SerializerMethodField()

    def get_device_type(self, obj):
        return obj.device_type.name if obj.device_type else 'Unknown'

    def get_mac_address(self, obj):
        return None

    def get_description(self, obj):
        return None

    def get_snmp_enabled(self, obj):
        return bool(obj.snmp_community)

    def get_is_active(self, obj):
        return obj.status in ('online', 'unreachable', 'maintenance')

    def get_snmp_community(self, obj):
        return obj.snmp_community or ''

    class Meta:
        model = Device
        fields = (
            'id', 'name', 'device_type', 'device_type_id',
            'ip_address', 'mac_address', 'location', 'description',
            'status', 'is_active', 'last_seen',
            'snmp_enabled', 'snmp_community',
            'assigned_to', 'assigned_to_username',
            'created_at', 'updated_at',
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
