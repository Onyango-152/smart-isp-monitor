from django.urls import path
from . import views

app_name = 'metrics'

urlpatterns = [
    # Root snapshot list — GET /api/metrics/?device=<id>
    # Returns flat MetricModel-compatible snapshots (one per device).
    path('',                             views.DeviceMetricSnapshotListView.as_view(), name='snapshot-list'),

    # Metric type management
    path('types/',                       views.MetricListView.as_view(),              name='type-list'),
    path('types/<int:pk>/',              views.MetricDetailView.as_view(),            name='type-detail'),

    # Metric readings (time-series data)
    path('readings/',                    views.MetricReadingListView.as_view(),       name='reading-list'),
    path('readings/<int:pk>/',           views.MetricReadingDetailView.as_view(),     name='reading-detail'),
    path('device/<int:device_id>/',      views.DeviceMetricsView.as_view(),          name='device-metrics'),

    # Metric thresholds and alerting
    path('thresholds/',                  views.MetricThresholdListView.as_view(),     name='threshold-list'),
    path('thresholds/<int:pk>/',         views.MetricThresholdDetailView.as_view(),   name='threshold-detail'),

    # Metric predictions
    path('predictions/',                 views.MetricPredictionListView.as_view(),    name='prediction-list'),
]
