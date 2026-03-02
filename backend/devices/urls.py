from django.urls import path
from . import views

app_name = 'devices'

urlpatterns = [
    # Device management endpoints
    path('list/',            views.DeviceListView.as_view(),         name='device-list'),
    path('<int:pk>/',        views.DeviceDetailView.as_view(),       name='device-detail'),
    path('<int:pk>/status/', views.DeviceStatusView.as_view(),       name='device-status'),

    # Device type management
    path('types/',           views.DeviceTypeListView.as_view(),     name='type-list'),
    path('types/<int:pk>/',  views.DeviceTypeDetailView.as_view(),   name='type-detail'),
]
