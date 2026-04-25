from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Avg, Max, Min
from django.utils import timezone
from datetime import timedelta

from .models import Metric, MetricReading, MetricThreshold, MetricPrediction
from devices.models import Device
from organisations.models import Membership
from .serializers import (
    MetricSerializer, MetricReadingSerializer, MetricThresholdSerializer,
    MetricPredictionSerializer,
)


def _user_device_ids(user):
    if user.role == 'admin':
        return Device.objects.values_list('id', flat=True)
    org_ids = Membership.objects.filter(user=user).values_list('organisation_id', flat=True)
    return Device.objects.filter(organisation_id__in=org_ids).values_list('id', flat=True)

# Maps normalised metric names (lower-case, spaces→underscores) to the flat
# field names the Flutter MetricModel.fromJson expects.
_METRIC_FIELD_MAP = {
    'latency':            'latency_ms',
    'latency_ms':         'latency_ms',
    'packet_loss':        'packet_loss_pct',
    'packet_loss_pct':    'packet_loss_pct',
    'bandwidth_in':       'bandwidth_in_bps',
    'bandwidth_in_bps':   'bandwidth_in_bps',
    'bandwidth_out':      'bandwidth_out_bps',
    'bandwidth_out_bps':  'bandwidth_out_bps',
    'cpu_usage':          'cpu_usage_pct',
    'cpu_usage_pct':      'cpu_usage_pct',
    'cpu':                'cpu_usage_pct',
    'memory_usage':       'memory_usage_pct',
    'memory_usage_pct':   'memory_usage_pct',
    'memory':             'memory_usage_pct',
    'interface_errors':   'interface_errors',
    'errors':             'interface_errors',
    'uptime':             'uptime_seconds',
    'uptime_seconds':     'uptime_seconds',
    'mac_table_entries':  'mac_table_entries',
    'mac_table':          'mac_table_entries',
    'power_load':         'power_load_pct',
    'power_load_pct':     'power_load_pct',
}


class DeviceMetricSnapshotListView(APIView):
    """
    GET /api/metrics/?device=<id>

    Returns one flat snapshot object per device, aggregating the latest
    metric reading of each type into the format Flutter's MetricModel
    expects.  Readings older than 7 days are excluded.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        device_id = request.query_params.get('device')
        cutoff    = timezone.now() - timedelta(days=7)

        devices = (
            Device.objects.filter(pk=device_id) if device_id
            else Device.objects.filter(id__in=_user_device_ids(request.user))
        )

        snapshots = []
        for device in devices:
            readings = (
                MetricReading.objects
                .filter(device=device, timestamp__gte=cutoff)
                .select_related('metric')
                .order_by('metric_id', '-timestamp')
            )
            # Pick the latest reading per metric type (first occurrence after
            # ordering descending by timestamp within each metric group).
            seen:    set  = set()
            latest:  list = []
            for r in readings:
                if r.metric_id not in seen:
                    seen.add(r.metric_id)
                    latest.append(r)

            snapshot: dict = {
                'id':               device.id,
                'device_id':        device.id,
                'latency_ms':       None,
                'packet_loss_pct':  None,
                'bandwidth_in_bps': None,
                'bandwidth_out_bps':None,
                'cpu_usage_pct':    None,
                'memory_usage_pct': None,
                'interface_errors': None,
                'uptime_seconds':   None,
                'mac_table_entries': None,
                'power_load_pct':   None,
                'poll_method':      'auto',
                'recorded_at':      timezone.now().isoformat(),
            }
            for r in latest:
                key = r.metric.name.lower().replace('-', '_').replace(' ', '_')
                flat_field = _METRIC_FIELD_MAP.get(key)
                if flat_field:
                    snapshot[flat_field] = r.value

            snapshots.append(snapshot)

        return Response(snapshots)


class MetricListView(generics.ListCreateAPIView):
    """
    Metric Types Management
    
    GET: List all metric types (Bandwidth, Latency, Packet Loss, etc.)
    POST: Create a new metric type definition
    """
    queryset = Metric.objects.all().order_by('name')
    serializer_class = MetricSerializer
    permission_classes = [IsAuthenticated]


class MetricDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Metric Type Detail View
    
    GET: Retrieve a specific metric type
    PUT: Update a metric type
    DELETE: Delete a metric type
    """
    queryset = Metric.objects.all()
    serializer_class = MetricSerializer
    permission_classes = [IsAuthenticated]


class MetricReadingListView(generics.ListCreateAPIView):
    serializer_class   = MetricReadingSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = MetricReading.objects.filter(
            device_id__in=_user_device_ids(self.request.user)
        ).order_by('-timestamp')
        device_id = self.request.query_params.get('device_id')
        metric_id = self.request.query_params.get('metric_id')
        if device_id:
            qs = qs.filter(device_id=device_id)
        if metric_id:
            qs = qs.filter(metric_id=metric_id)
        return qs


class MetricReadingDetailView(generics.RetrieveDestroyAPIView):
    """
    Metric Reading Detail View
    
    GET: Retrieve a specific metric reading
    DELETE: Remove a metric reading (readings shouldn't be deleted normally)
    """
    queryset = MetricReading.objects.all()
    serializer_class = MetricReadingSerializer
    permission_classes = [IsAuthenticated]


class DeviceMetricsView(APIView):
    """
    Device Metrics Summary
    
    GET: Get aggregated metrics for a specific device
    - Returns latest readings, averages, min/max values
    - Can filter by time range (last_hour, last_day, last_week)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, device_id):
        """Get device metrics summary"""
        try:
            device = Device.objects.get(pk=device_id, id__in=_user_device_ids(request.user))
        except Device.DoesNotExist:
            return Response({'error': 'Device not found'}, status=status.HTTP_404_NOT_FOUND)

        time_range = request.query_params.get('range', 'last_day')
        now = timezone.now()

        # Calculate time filters
        if time_range == 'last_hour':
            start_time = now - timedelta(hours=1)
        elif time_range == 'last_day':
            start_time = now - timedelta(days=1)
        elif time_range == 'last_week':
            start_time = now - timedelta(days=7)
        else:
            start_time = now - timedelta(days=1)

        # Get all metrics for this device
        readings = MetricReading.objects.filter(
            device=device,
            timestamp__gte=start_time
        )

        # Aggregate by metric
        metrics_summary = {}
        for metric in Metric.objects.all():
            metric_readings = readings.filter(metric=metric)
            if metric_readings.exists():
                metrics_summary[metric.name] = {
                    'unit': metric.unit,
                    'latest': metric_readings.latest('timestamp').value,
                    'average': metric_readings.aggregate(Avg('value'))['value__avg'],
                    'max': metric_readings.aggregate(Max('value'))['value__max'],
                    'min': metric_readings.aggregate(Min('value'))['value__min'],
                    'count': metric_readings.count(),
                }

        return Response({
            'device': device.name,
            'time_range': time_range,
            'metrics': metrics_summary,
        })


class MetricThresholdListView(generics.ListCreateAPIView):
    serializer_class   = MetricThresholdSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = MetricThreshold.objects.filter(device_id__in=_user_device_ids(self.request.user))
        device_id = self.request.query_params.get('device')
        metric_id = self.request.query_params.get('metric')
        if device_id:
            qs = qs.filter(device_id=device_id)
        if metric_id:
            qs = qs.filter(metric_id=metric_id)
        return qs


class MetricThresholdDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class   = MetricThresholdSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return MetricThreshold.objects.filter(device_id__in=_user_device_ids(self.request.user))


class MetricPredictionListView(generics.ListAPIView):
    serializer_class   = MetricPredictionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = MetricPrediction.objects.filter(
            device_id__in=_user_device_ids(self.request.user)
        ).order_by('-generated_at')
        device_id = self.request.query_params.get('device')
        metric_id = self.request.query_params.get('metric')
        if device_id:
            qs = qs.filter(device_id=device_id)
        if metric_id:
            qs = qs.filter(metric_id=metric_id)
        return qs

