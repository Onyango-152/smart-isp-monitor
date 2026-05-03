from rest_framework import serializers
from .models import AlertRule, Alert, NotificationChannel


class AlertRuleSerializer(serializers.ModelSerializer):
    device_name = serializers.CharField(
        source='device.name', read_only=True, default=None
    )

    class Meta:
        model  = AlertRule
        fields = (
            'id', 'name', 'description', 'device', 'device_name',
            'metric', 'condition', 'threshold', 'severity',
            'enabled', 'created_at', 'updated_at',
        )


class AlertSerializer(serializers.ModelSerializer):
    rule_name          = serializers.CharField(source='rule.name',   read_only=True, default=None)
    device_name        = serializers.CharField(source='device.name', read_only=True)
    device_id          = serializers.IntegerField(read_only=True)
    acknowledged_by_username = serializers.CharField(
        source='acknowledged_by.username', read_only=True, default=None
    )
    reported_by_username = serializers.CharField(
        source='reported_by.username', read_only=True, default=None
    )
    # Flattened fields expected by the mobile AlertModel
    alert_type         = serializers.SerializerMethodField()
    is_resolved        = serializers.SerializerMethodField()
    is_acknowledged    = serializers.SerializerMethodField()
    details            = serializers.SerializerMethodField()

    def get_alert_type(self, obj):
        return obj.rule.name if obj.rule else obj.severity

    def get_is_resolved(self, obj):
        return obj.status == 'resolved'

    def get_is_acknowledged(self, obj):
        return obj.status in ('acknowledged', 'resolved')

    def get_details(self, obj):
        return None

    class Meta:
        model  = Alert
        fields = (
            'id', 'rule', 'rule_name', 'device', 'device_id', 'device_name',
            'alert_type', 'severity', 'status', 'message', 'details',
            'is_resolved', 'is_acknowledged',
            'triggered_at', 'acknowledged_at', 'resolved_at',
            'acknowledged_by', 'acknowledged_by_username',
            'customer_reported', 'reported_by', 'reported_by_username', 'reported_at',
        )
        read_only_fields = ('id', 'triggered_at', 'acknowledged_at', 'resolved_at')


class NotificationChannelSerializer(serializers.ModelSerializer):
    class Meta:
        model  = NotificationChannel
        fields = ('id', 'channel_type', 'address', 'is_active', 'verified', 'created_at')
        read_only_fields = ('id', 'verified', 'created_at')