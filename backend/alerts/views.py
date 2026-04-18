from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone

from .models import Alert, AlertRule, NotificationChannel
from .serializers import (
    AlertSerializer, AlertRuleSerializer, NotificationChannelSerializer
)
from devices.models import Device
from users.permissions import IsTechnician


class AlertListView(generics.ListAPIView):
    """
    GET /api/alerts/
    Returns all alerts, newest first.
    Supports ?status= and ?device=<id> filters.
    """
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Alert.objects.select_related('device', 'rule').order_by('-triggered_at')
        status_filter = self.request.query_params.get('status')
        device_filter = self.request.query_params.get('device')
        if status_filter:
            qs = qs.filter(status=status_filter)
        if device_filter:
            qs = qs.filter(device_id=device_filter)
        return qs


class MyAlertsView(generics.ListAPIView):
    """
    GET /api/alerts/my-alerts/
    Returns alerts for devices assigned to the requesting user.
    """
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        device_ids = Device.objects.filter(
            assigned_to=self.request.user
        ).values_list('id', flat=True)
        return Alert.objects.filter(
            device_id__in=device_ids
        ).order_by('-triggered_at')


class AlertDetailView(generics.RetrieveAPIView):
    """GET /api/alerts/<pk>/"""
    queryset           = Alert.objects.all()
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]


class AcknowledgeAlertView(APIView):
    """POST /api/alerts/<pk>/acknowledge/"""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            alert = Alert.objects.get(pk=pk)
        except Alert.DoesNotExist:
            return Response({'error': 'Alert not found.'}, status=status.HTTP_404_NOT_FOUND)

        if alert.status == 'resolved':
            return Response(
                {'error': 'Cannot acknowledge a resolved alert.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        alert.status          = 'acknowledged'
        alert.acknowledged_by = request.user
        alert.acknowledged_at = timezone.now()
        alert.save()
        return Response(AlertSerializer(alert).data)


class ResolveAlertView(APIView):
    """POST /api/alerts/<pk>/resolve/"""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            alert = Alert.objects.get(pk=pk)
        except Alert.DoesNotExist:
            return Response({'error': 'Alert not found.'}, status=status.HTTP_404_NOT_FOUND)

        alert.status      = 'resolved'
        alert.resolved_at = timezone.now()
        alert.save()
        return Response(AlertSerializer(alert).data)


class AlertRuleListView(generics.ListCreateAPIView):
    """
    GET  /api/alerts/rules/  — any authenticated user
    POST /api/alerts/rules/  — technician, manager, admin only
    """
    queryset         = AlertRule.objects.all().order_by('-created_at')
    serializer_class = AlertRuleSerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsTechnician()]
        return [IsAuthenticated()]


class AlertRuleDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PUT / PATCH / DELETE /api/alerts/rules/<pk>/"""
    queryset           = AlertRule.objects.all()
    serializer_class   = AlertRuleSerializer
    permission_classes = [IsTechnician]


class NotificationChannelListView(generics.ListCreateAPIView):
    """GET /api/alerts/channels/  POST /api/alerts/channels/"""
    serializer_class   = NotificationChannelSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationChannel.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class NotificationChannelDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PUT / PATCH / DELETE /api/alerts/channels/<pk>/"""
    serializer_class   = NotificationChannelSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationChannel.objects.filter(user=self.request.user)


class ReportIssueView(APIView):
    """
    POST /api/alerts/report/
    Allows a customer to self-report a service issue.
    Creates a new Alert linked to their first assigned device.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        description = (request.data.get('description') or '').strip()
        if not description:
            return Response(
                {'error': 'Description is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        device = Device.objects.filter(assigned_to=request.user).first()
        if not device:
            return Response(
                {'error': 'No device assigned to your account.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        alert = Alert.objects.create(
            device=device,
            severity='medium',
            status='new',
            message=f'Customer reported: {description}',
        )
        return Response(
            {'message': 'Issue reported. A technician will follow up shortly.',
             'alert_id': alert.id},
            status=status.HTTP_201_CREATED,
        )
