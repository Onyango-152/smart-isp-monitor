from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone

from .models import Device, DeviceType
from .serializers import DeviceSerializer, DeviceTypeSerializer, DeviceStatusSerializer
from users.permissions import IsTechnician


class DeviceTypeListView(generics.ListCreateAPIView):
    queryset = DeviceType.objects.all()
    serializer_class = DeviceTypeSerializer
    permission_classes = [IsAuthenticated]


class DeviceTypeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = DeviceType.objects.all()
    serializer_class = DeviceTypeSerializer
    permission_classes = [IsAuthenticated]


class DeviceListView(generics.ListCreateAPIView):
    """
    GET  /api/devices/  — all roles can list
    POST /api/devices/  — technician, manager, admin only
    """
    queryset = Device.objects.all().order_by('name')
    serializer_class = DeviceSerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsTechnician()]
        return [IsAuthenticated()]

    def perform_create(self, serializer):
        assigned_to = serializer.validated_data.get('assigned_to')
        if assigned_to:
            serializer.save()
        else:
            serializer.save(assigned_to=self.request.user)


class MyDevicesView(generics.ListAPIView):
    """
    GET /api/devices/my-devices/
    Returns only the devices assigned to the requesting user.
    """
    serializer_class   = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Device.objects.filter(assigned_to=self.request.user).order_by('name')


class DeviceDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET        — any authenticated user
    PUT/PATCH  — technician, manager, admin
    DELETE     — manager, admin
    """
    queryset = Device.objects.all()
    serializer_class = DeviceSerializer

    def get_permissions(self):
        from users.permissions import IsManager
        if self.request.method == 'DELETE':
            return [IsManager()]
        if self.request.method in ('PUT', 'PATCH'):
            return [IsTechnician()]
        return [IsAuthenticated()]


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

