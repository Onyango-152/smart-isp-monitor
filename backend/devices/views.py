from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone

from .models import Device, DeviceType
from .serializers import DeviceSerializer, DeviceTypeSerializer, DeviceStatusSerializer
from organisations.models import Membership


def _user_org_ids(user):
    """Return the set of org IDs the user is a member of."""
    if user.role == 'admin':
        from organisations.models import Organisation
        return Organisation.objects.filter(is_active=True).values_list('id', flat=True)
    return Membership.objects.filter(user=user).values_list('organisation_id', flat=True)


def _scoped_devices(user):
    """Devices visible to this user based on org membership."""
    return Device.objects.filter(
        organisation_id__in=_user_org_ids(user)
    ).order_by('name')


class DeviceTypeListView(generics.ListCreateAPIView):
    queryset           = DeviceType.objects.all()
    serializer_class   = DeviceTypeSerializer
    permission_classes = [IsAuthenticated]


class DeviceTypeDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset           = DeviceType.objects.all()
    serializer_class   = DeviceTypeSerializer
    permission_classes = [IsAuthenticated]


class DeviceListView(generics.ListCreateAPIView):
    """
    GET  /api/devices/  — list devices in the user's organisations
    POST /api/devices/  — register a new device (technician/manager/admin only)
    """
    serializer_class   = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return _scoped_devices(self.request.user)

    def create(self, request, *args, **kwargs):
        if request.user.role not in ('technician', 'manager', 'admin'):
            return Response(
                {'error': 'Only technicians or managers can register devices.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        # Require an org to be specified and that the user belongs to it
        org_id = request.data.get('organisation')
        if not org_id:
            return Response(
                {'error': 'organisation is required when registering a device.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if str(org_id) not in [str(i) for i in _user_org_ids(request.user)]:
            return Response(
                {'error': 'You are not a member of that organisation.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().create(request, *args, **kwargs)


class MyDevicesView(generics.ListAPIView):
    """
    GET /api/devices/my-devices/
    For customers — devices in their organisations.
    """
    serializer_class   = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return _scoped_devices(self.request.user)


class DeviceDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class   = DeviceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return _scoped_devices(self.request.user)


class DeviceStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request, pk):
        try:
            device = _scoped_devices(request.user).get(pk=pk)
        except Device.DoesNotExist:
            return Response({'error': 'Device not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = DeviceStatusSerializer(data=request.data)
        if serializer.is_valid():
            device.status   = serializer.validated_data['status']
            device.last_seen = serializer.validated_data.get('last_seen', timezone.now())
            device.save()
            return Response(DeviceSerializer(device).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def get(self, request, pk):
        try:
            device = _scoped_devices(request.user).get(pk=pk)
            return Response({
                'id': device.id, 'name': device.name,
                'status': device.status, 'last_seen': device.last_seen,
            })
        except Device.DoesNotExist:
            return Response({'error': 'Device not found'}, status=status.HTTP_404_NOT_FOUND)
