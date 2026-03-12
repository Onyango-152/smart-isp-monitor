from rest_framework import serializers
from .models import MonitoringTask, MonitoringReport, SystemHealth


class MonitoringTaskSerializer(serializers.ModelSerializer):
    device_name = serializers.CharField(source='device.name', read_only=True, default=None)
    task_type_display = serializers.CharField(source='get_task_type_display', read_only=True)

    class Meta:
        model = MonitoringTask
        fields = (
            'id', 'name', 'description', 'device', 'device_name',
            'task_type', 'task_type_display', 'interval', 'timeout',
            'enabled', 'last_run', 'last_status', 'created_at', 'updated_at',
        )
        read_only_fields = ('id', 'last_run', 'last_status', 'created_at', 'updated_at')


class MonitoringReportSerializer(serializers.ModelSerializer):
    task_name = serializers.CharField(source='task.name', read_only=True)

    class Meta:
        model = MonitoringReport
        fields = (
            'id', 'task', 'task_name', 'executed_at',
            'status', 'duration_ms', 'details', 'metrics_collected',
        )
        read_only_fields = ('id', 'executed_at')


class SystemHealthSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemHealth
        fields = (
            'id', 'healthy_devices', 'total_devices', 'total_alerts',
            'failed_tasks', 'total_tasks', 'uptime_percentage', 'last_update',
        )
        read_only_fields = fields

