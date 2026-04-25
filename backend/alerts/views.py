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
from organisations.models import Membership


def _user_device_ids(user):
    """Devices the user can see, scoped by org membership."""
    if user.role == 'admin':
        return Device.objects.values_list('id', flat=True)
    org_ids = Membership.objects.filter(user=user).values_list('organisation_id', flat=True)
    return Device.objects.filter(organisation_id__in=org_ids).values_list('id', flat=True)


class AlertListView(generics.ListAPIView):
    """
    GET /api/alerts/  -- all alerts scoped to the user's organisations.
    Supports ?status= and ?device= filters.
    """
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Alert.objects.filter(
            device_id__in=_user_device_ids(self.request.user)
        ).select_related('rule', 'rule__device').order_by('-triggered_at')
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
    Alerts for devices in the requesting user's organisations.
    """
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Alert.objects.filter(
            device_id__in=_user_device_ids(self.request.user)
        ).order_by('-triggered_at')


class AlertDetailView(generics.RetrieveAPIView):
    serializer_class   = AlertSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Alert.objects.filter(device_id__in=_user_device_ids(self.request.user))


class AcknowledgeAlertView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            alert = Alert.objects.get(pk=pk, device_id__in=_user_device_ids(request.user))
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
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            alert = Alert.objects.get(pk=pk, device_id__in=_user_device_ids(request.user))
        except Alert.DoesNotExist:
            return Response({'error': 'Alert not found.'}, status=status.HTTP_404_NOT_FOUND)

        alert.status = 'resolved'
        alert.save()
        return Response(AlertSerializer(alert).data)


class AlertRuleListView(generics.ListCreateAPIView):
    serializer_class   = AlertRuleSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return AlertRule.objects.filter(
            device_id__in=_user_device_ids(self.request.user)
        ).order_by('-created_at')


class AlertRuleDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class   = AlertRuleSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return AlertRule.objects.filter(device_id__in=_user_device_ids(self.request.user))


class NotificationChannelListView(generics.ListCreateAPIView):
    serializer_class   = NotificationChannelSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Users only see their own notification channels
        return NotificationChannel.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class NotificationChannelDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class   = NotificationChannelSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationChannel.objects.filter(user=self.request.user)
