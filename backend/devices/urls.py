from django.urls import path
from . import views

app_name = 'devices'

urlpatterns = [
    # Root list — GET /api/devices/ → matches devicesEndpoint in Flutter
    path('',             views.DeviceListView.as_view(),         name='device-list'),

    # Customer-scoped list — GET /api/devices/my-devices/
    path('my-devices/',  views.MyDevicesView.as_view(),          name='my-devices'),

    # Device management endpoints
    path('list/',            views.DeviceListView.as_view(),         name='device-list-legacy'),
    path('<int:pk>/',        views.DeviceDetailView.as_view(),       name='device-detail'),
    path('<int:pk>/status/', views.DeviceStatusView.as_view(),       name='device-status'),

    # Device type management
    path('types/',           views.DeviceTypeListView.as_view(),     name='type-list'),
    path('types/<int:pk>/',  views.DeviceTypeDetailView.as_view(),   name='type-detail'),
]
