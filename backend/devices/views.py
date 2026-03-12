from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone

from .models import Device, DeviceType
from .serializers import DeviceSerializer, DeviceTypeSerializer, DeviceStatusSerializer


class DeviceTypeListView(generics.ListCreateAPIView):
    """
    Device Type Management
    
    GET: List all device types (Router, Switch, Firewall, etc.)
    POST: Create a new device type (admin only)
    """
    queryset = DeviceType.objects.all()
    serializer_class = DeviceTypeSerializer
    permission_classes = [IsAuthenticated]


class DeviceTypeDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Device Type Detail View
    
    GET: Retrieve a specific device type
    PUT: Update a device type
    DELETE: Delete a device type
    """
    queryset = DeviceType.objects.all()
    serializer_class = DeviceTypeSerializer
    permission_classes = [IsAuthenticated]


class DeviceListView(generics.ListCreateAPIView):
    """
    Device Management
    
    GET: List all devices with status and configuration
    POST: Register a new device for monitoring
    """
    queryset = Device.objects.all().order_by('name')
    serializer_class = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        """Auto-assign device to current user if not specified"""
        if not serializer.validated_data.get('assigned_to'):
            serializer.save(assigned_to=self.request.user)
        else:
            serializer.save()


class MyDevicesView(generics.ListAPIView):
    """
    GET /api/devices/my-devices/
    Returns only the devices assigned to the requesting user.
    Intended for the customer portal — each customer sees only their equipment.
    """
    serializer_class   = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Device.objects.filter(assigned_to=self.request.user).order_by('name')


class DeviceDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Device Detail View
    
    GET: Get detailed information about a specific device
    PUT: Update device configuration
    DELETE: Remove device from monitoring
    """
    queryset = Device.objects.all()
    serializer_class = DeviceSerializer
    permission_classes = [IsAuthenticated]


class DeviceStatusView(APIView):
    """
    Device Status Update
    
    PUT: Update device status (online, offline, unreachable, maintenance)
    
    This is used when the monitoring system polls devices
    and updates their status based on connectivity.
    """
    permission_classes = [IsAuthenticated]

    def put(self, request, pk):
        """Update device status"""
        try:
            device = Device.objects.get(pk=pk)
        except Device.DoesNotExist:
            return Response(
                {'error': 'Device not found'},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = DeviceStatusSerializer(data=request.data)
        if serializer.is_valid():
            device.status = serializer.validated_data['status']
            device.last_seen = serializer.validated_data.get(
                'last_seen',
                timezone.now()
            )
            device.save()
            return Response(
                DeviceSerializer(device).data,
                status=status.HTTP_200_OK
            )
        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )

    def get(self, request, pk):
        """Get current device status"""
        try:
            device = Device.objects.get(pk=pk)
            return Response({
                'id': device.id,
                'name': device.name,
                'status': device.status,
                'last_seen': device.last_seen,
            })
        except Device.DoesNotExist:
            return Response(
                {'error': 'Device not found'},
                status=status.HTTP_404_NOT_FOUND
            )

