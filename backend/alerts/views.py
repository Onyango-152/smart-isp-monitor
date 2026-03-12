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


class AlertListView(generics.ListAPIView):
    """
    GET /api/alerts/list/
    Returns all alerts, newest first.
    Supports ?status=open|acknowledged|resolved and ?device=<id> filters.
    """
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Alert.objects.select_related('rule', 'rule__device').order_by('-triggered_at')
        status_filter = self.request.query_params.get('status')
        device_filter = self.request.query_params.get('device')
        if status_filter:
            qs = qs.filter(status=status_filter)
        if device_filter:
            qs = qs.filter(rule__device_id=device_filter)
        return qs


class MyAlertsView(generics.ListAPIView):
    """
    GET /api/alerts/my-alerts/
    Returns alerts for devices assigned to the requesting user.
    Intended for the customer portal.
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
    """
    GET /api/alerts/<pk>/
    """
    queryset           = Alert.objects.all()
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]


class AcknowledgeAlertView(APIView):
    """
    POST /api/alerts/<pk>/acknowledge/
    Marks an alert as acknowledged by the requesting user.
    """
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
    """
    POST /api/alerts/<pk>/resolve/
    Marks an alert as resolved.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            alert = Alert.objects.get(pk=pk)
        except Alert.DoesNotExist:
            return Response({'error': 'Alert not found.'}, status=status.HTTP_404_NOT_FOUND)

        alert.status = 'resolved'
        alert.save()
        return Response(AlertSerializer(alert).data)


class AlertRuleListView(generics.ListCreateAPIView):
    """
    GET  /api/alerts/rules/  â€” list all rules
    POST /api/alerts/rules/  â€” create a rule
    """
    queryset           = AlertRule.objects.all().order_by('-created_at')
    serializer_class   = AlertRuleSerializer
    permission_classes = [IsAuthenticated]


class AlertRuleDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET / PUT / PATCH / DELETE /api/alerts/rules/<pk>/
    """
    queryset           = AlertRule.objects.all()
    serializer_class   = AlertRuleSerializer
    permission_classes = [IsAuthenticated]


class NotificationChannelListView(generics.ListCreateAPIView):
    """
    GET  /api/alerts/channels/
    POST /api/alerts/channels/
    """
    queryset           = NotificationChannel.objects.all()
    serializer_class   = NotificationChannelSerializer
    permission_classes = [IsAuthenticated]


class NotificationChannelDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET / PUT / PATCH / DELETE /api/alerts/channels/<pk>/
    """
    queryset           = NotificationChannel.objects.all()
    serializer_class   = NotificationChannelSerializer
    permission_classes = [IsAuthenticated]

