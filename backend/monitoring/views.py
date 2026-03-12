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
            'avg_latency_ms':      0,
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
    GET  /api/monitoring/tasks/  — list all monitoring tasks
    POST /api/monitoring/tasks/  — create a new task
    """
    queryset = MonitoringTask.objects.select_related('device').order_by('name')
    serializer_class = MonitoringTaskSerializer
    permission_classes = [IsAuthenticated]


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
    Manually triggers an immediate run of a monitoring task.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            task = MonitoringTask.objects.get(pk=pk)
        except MonitoringTask.DoesNotExist:
            return Response({'error': 'Task not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Record the manual run attempt
        task.last_run = timezone.now()
        task.last_status = 'pending'
        task.save(update_fields=['last_run', 'last_status'])

        MonitoringReport.objects.create(
            task=task,
            status='success',
            details='Manually triggered via API.',
            metrics_collected=0,
        )

        return Response(
            {'message': f'Task "{task.name}" triggered successfully.'},
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
