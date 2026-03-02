from rest_framework import serializers
from .models import Metric, MetricReading, MetricThreshold


class MetricSerializer(serializers.ModelSerializer):
    """
    Serializer for Metric Types (Bandwidth, Latency, Packet Loss, etc.)
    
    Fields:
    - id: Unique identifier
    - name: Metric name
    - unit: Unit of measurement (Mbps, ms, %, etc.)
    - description: Description of this metric
    """
    class Meta:
        model = Metric
        fields = ('id', 'name', 'unit', 'description')


class MetricReadingSerializer(serializers.ModelSerializer):
    """
    Serializer for historical Metric Readings (time-series data)
    
    Fields:
    - id: Unique identifier
    - device: Device being measured
    - metric: Type of metric
    - value: The measured value
    - timestamp: When it was measured
    """
    metric_name = serializers.CharField(source='metric.name', read_only=True)
    metric_unit = serializers.CharField(source='metric.unit', read_only=True)
    device_name = serializers.CharField(source='device.name', read_only=True)

    class Meta:
        model = MetricReading
        fields = (
            'id', 'device', 'device_name', 'metric', 'metric_name',
            'metric_unit', 'value', 'timestamp'
        )
        read_only_fields = ('timestamp',)


class MetricThresholdSerializer(serializers.ModelSerializer):
    """
    Serializer for Metric Thresholds (Alert triggers)
    
    Fields:
    - id: Unique identifier
    - device: Device this threshold applies to
    - metric: Metric type
    - warning_threshold: Value that triggers warning
    - critical_threshold: Value that triggers critical alert
    - is_active: Whether this threshold is active
    """
    device_name = serializers.CharField(source='device.name', read_only=True)
    metric_name = serializers.CharField(source='metric.name', read_only=True)

    class Meta:
        model = MetricThreshold
        fields = (
            'id', 'device', 'device_name', 'metric', 'metric_name',
            'warning_threshold', 'critical_threshold', 'is_active',
            'created_at', 'updated_at'
        )
        read_only_fields = ('created_at', 'updated_at')
