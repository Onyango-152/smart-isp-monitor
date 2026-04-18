from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from datetime import timedelta

from .models import MonitoringTask, MonitoringReport, SystemHealth
from .serializers import (
    MonitoringTaskSerializer, MonitoringReportSerializer, SystemHealthSerializer
)
from users.permissions import IsTechnician


class DashboardSummaryView(APIView):
    """
    GET /api/dashboard/summary/
    Network-wide KPIs for the manager/technician dashboard.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from devices.models import Device
        from alerts.models import Alert
        from django.db.models import Avg, F, ExpressionWrapper, fields as db_fields

        total       = Device.objects.count()
        online      = Device.objects.filter(status='online').count()
        offline     = Device.objects.filter(status='offline').count()
        unreachable = Device.objects.filter(status='unreachable').count()

        active_alerts  = Alert.objects.filter(status='new').count()
        critical       = Alert.objects.filter(status='new', severity='critical').count()

        week_ago           = timezone.now() - timedelta(days=7)
        faults_this_week   = Alert.objects.filter(triggered_at__gte=week_ago).count()

        mttr_qs = (
            Alert.objects
            .filter(status='resolved', resolved_at__isnull=False)
            .annotate(
                resolution_time=ExpressionWrapper(
                    F('resolved_at') - F('triggered_at'),
                    output_field=db_fields.DurationField(),
                )
            )
            .aggregate(avg=Avg('resolution_time'))
        )
        avg_duration = mttr_qs['avg']
        mttr_minutes = int(avg_duration.total_seconds() / 60) if avg_duration else 0

        # Compute real average latency from the last hour of readings
        from metrics.models import MetricReading, Metric
        avg_latency_ms = 0
        latency_metric = Metric.objects.filter(name='latency_ms').first()
        if latency_metric:
            one_hour_ago = timezone.now() - timedelta(hours=1)
            avg = (
                MetricReading.objects
                .filter(metric=latency_metric, timestamp__gte=one_hour_ago)
                .aggregate(avg=Avg('value'))['avg']
            )
            avg_latency_ms = round(avg, 1) if avg else 0

        return Response({
            'total_devices':       total,
            'online_devices':      online,
            'offline_devices':     offline,
            'degraded_devices':    unreachable,
            'active_alerts':       active_alerts,
            'critical_alerts':     critical,
            'faults_this_week':    faults_this_week,
            'avg_mttr_minutes':    mttr_minutes,
            'network_uptime_pct':  round(online / total * 100, 2) if total else 0.0,
            'avg_latency_ms':      avg_latency_ms,
        })


class CustomerDashboardView(APIView):
    """
    GET /api/dashboard/customer/
    Simplified service-status view for the logged-in customer.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from devices.models import Device
        from alerts.models import Alert

        devices    = Device.objects.filter(assigned_to=request.user)
        device_ids = devices.values_list('id', flat=True)
        alerts     = Alert.objects.filter(device_id__in=device_ids)
        active     = alerts.filter(status='new')

        return Response({
            'total_devices':   devices.count(),
            'online_devices':  devices.filter(status='online').count(),
            'offline_devices': devices.filter(status='offline').count(),
            'active_alerts':   active.count(),
            'critical_alerts': active.filter(severity='critical').count(),
            'service_status':  (
                'online'  if devices.filter(status='online').exists() else
                'degraded' if devices.filter(status='unreachable').exists() else
                'offline'
            ),
        })


class MonitoringTaskListView(generics.ListCreateAPIView):
    """
    GET  /api/monitoring/tasks/  — any authenticated user
    POST /api/monitoring/tasks/  — technician, manager, admin only
    """
    queryset         = MonitoringTask.objects.select_related('device').order_by('name')
    serializer_class = MonitoringTaskSerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsTechnician()]
        return [IsAuthenticated()]


class MonitoringTaskDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET / PUT / PATCH / DELETE /api/monitoring/tasks/<pk>/
    """
    queryset = MonitoringTask.objects.select_related('device')
    serializer_class = MonitoringTaskSerializer
    permission_classes = [IsAuthenticated]


class RunMonitoringTaskView(APIView):
    """
    POST /api/monitoring/tasks/<pk>/run/
    Manually triggers an immediate run of a monitoring task using real
    SNMP polling (if the device has an SNMP community string) or ICMP
    ping as a fallback.
    """
    permission_classes = [IsTechnician]

    def post(self, request, pk):
        try:
            task = MonitoringTask.objects.get(pk=pk)
        except MonitoringTask.DoesNotExist:
            return Response({'error': 'Task not found.'}, status=status.HTTP_404_NOT_FOUND)

        device = task.device
        if not device:
            return Response({'error': 'Task has no associated device.'}, status=status.HTTP_400_BAD_REQUEST)

        # Mark as running
        task.last_run    = timezone.now()
        task.last_status = 'running'
        task.save(update_fields=['last_run', 'last_status'])

        collected = 0
        run_status = 'success'
        details    = ''

        try:
            if device.snmp_community:
                # ── SNMP poll ──────────────────────────────────────────
                from utils.snmp_poller import poll_device, save_poll_results
                results = poll_device(device)
                if results:
                    save_poll_results(device, results)
                    collected = len(results)
                    details   = f'SNMP poll returned {collected} metric(s): {list(results.keys())}'
                else:
                    run_status = 'failed'
                    details    = 'SNMP poll returned no data. Check community string and device reachability.'
            else:
                # ── ICMP ping fallback ─────────────────────────────────
                from utils.icmp_checker import ping_host, save_ping_results
                ping_results = ping_host(str(device.ip_address))
                save_ping_results(device, ping_results)
                collected = 2  # latency_ms + packet_loss_pct
                if ping_results['reachable']:
                    details = (
                        f'Ping OK — latency {ping_results["latency_ms"]} ms, '
                        f'loss {ping_results["packet_loss_pct"]}%'
                    )
                else:
                    run_status = 'failed'
                    details    = f'Host {device.ip_address} is unreachable (100% packet loss).'

            # Update device last_seen on success
            if run_status == 'success':
                device.last_seen = timezone.now()
                device.save(update_fields=['last_seen'])

        except Exception as exc:
            run_status = 'failed'
            details    = f'Execution error: {exc}'
            import logging
            logging.getLogger(__name__).warning('RunMonitoringTask error for task %s: %s', pk, exc)

        task.last_status = run_status
        task.save(update_fields=['last_status'])

        report = MonitoringReport.objects.create(
            task=task,
            status=run_status,
            details=details,
            metrics_collected=collected,
        )

        return Response(
            {
                'message':    f'Task "{task.name}" executed ({run_status}).',
                'status':     run_status,
                'details':    details,
                'report_id':  report.id,
                'metrics_collected': collected,
            },
            status=status.HTTP_200_OK,
        )


class MonitoringReportListView(generics.ListAPIView):
    """
    GET /api/monitoring/reports/
    Supports ?task=<id> filter.
    """
    serializer_class = MonitoringReportSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = MonitoringReport.objects.select_related('task').order_by('-executed_at')
        task_id = self.request.query_params.get('task')
        if task_id:
            qs = qs.filter(task_id=task_id)
        return qs


class MonitoringReportDetailView(generics.RetrieveAPIView):
    """
    GET /api/monitoring/reports/<pk>/
    """
    queryset = MonitoringReport.objects.select_related('task')
    serializer_class = MonitoringReportSerializer
    permission_classes = [IsAuthenticated]


class SystemHealthView(APIView):
    """
    GET /api/monitoring/health/
    Returns the latest system health snapshot, or computes one on the fly.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        health = SystemHealth.objects.order_by('-last_update').first()
        if health:
            return Response(SystemHealthSerializer(health).data)

        # No snapshot yet — return live counts
        from devices.models import Device
        from alerts.models import Alert
        total = Device.objects.count()
        healthy = Device.objects.filter(status='online').count()
        active_alerts = Alert.objects.filter(status='open').count()
        return Response({
            'healthy_devices': healthy,
            'total_devices': total,
            'total_alerts': active_alerts,
            'failed_tasks': 0,
            'total_tasks': MonitoringTask.objects.count(),
            'uptime_percentage': round((healthy / total * 100) if total else 100.0, 2),
            'last_update': timezone.now(),
        })


class MonitoringStatsView(APIView):
    """
    GET /api/monitoring/stats/
    Aggregate statistics for the monitoring dashboard.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        total_tasks = MonitoringTask.objects.count()
        enabled_tasks = MonitoringTask.objects.filter(enabled=True).count()
        total_reports = MonitoringReport.objects.count()
        failed_reports = MonitoringReport.objects.filter(status='failed').count()
        recent_reports = MonitoringReport.objects.order_by('-executed_at')[:10]

        return Response({
            'total_tasks': total_tasks,
            'enabled_tasks': enabled_tasks,
            'total_reports': total_reports,
            'failed_reports': failed_reports,
            'success_rate': round(
                ((total_reports - failed_reports) / total_reports * 100)
                if total_reports else 100.0,
                2,
            ),
            'recent_reports': MonitoringReportSerializer(recent_reports, many=True).data,
        })


class ReportExportView(APIView):
    """
    GET /api/monitoring/export/?format=csv&start=YYYY-MM-DD&end=YYYY-MM-DD

    Streams a CSV file containing all MetricReadings and alert counts for the
    requested date range.  Defaults to the last 7 days when dates are omitted.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        import csv
        import io
        from datetime import datetime
        from django.http import HttpResponse
        from django.utils.timezone import make_aware, is_naive
        from metrics.models import MetricReading
        from alerts.models import Alert

        start_str = request.query_params.get('start')
        end_str   = request.query_params.get('end')

        try:
            start_dt = (
                datetime.strptime(start_str, '%Y-%m-%d')
                if start_str
                else (timezone.now() - timedelta(days=7)).replace(
                    hour=0, minute=0, second=0, microsecond=0, tzinfo=None
                )
            )
            end_dt = (
                datetime.strptime(end_str, '%Y-%m-%d')
                if end_str
                else timezone.now().replace(tzinfo=None)
            )
        except ValueError:
            return Response(
                {'error': 'Invalid date format. Use YYYY-MM-DD.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Make timezone-aware
        if is_naive(start_dt):
            start_dt = make_aware(start_dt)
        if is_naive(end_dt):
            end_dt = make_aware(end_dt.replace(hour=23, minute=59, second=59))

        readings = (
            MetricReading.objects
            .filter(timestamp__gte=start_dt, timestamp__lte=end_dt)
            .select_related('device', 'metric')
            .order_by('device__name', '-timestamp')
        )

        # Pre-aggregate alert counts per device in the range
        alerts = (
            Alert.objects
            .filter(triggered_at__gte=start_dt, triggered_at__lte=end_dt)
            .values_list('device_id', flat=True)
        )
        alert_counts: dict = {}
        for device_id in alerts:
            alert_counts[device_id] = alert_counts.get(device_id, 0) + 1

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow([
            'device_name', 'ip_address', 'metric', 'value', 'unit', 'timestamp', 'alert_count',
        ])
        for r in readings:
            writer.writerow([
                r.device.name,
                r.device.ip_address,
                r.metric.name,
                r.value,
                r.metric.unit,
                r.timestamp.isoformat(),
                alert_counts.get(r.device_id, 0),
            ])

        response = HttpResponse(output.getvalue(), content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="network_report.csv"'
        response['Access-Control-Expose-Headers'] = 'Content-Disposition'
        return response
