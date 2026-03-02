from django.urls import path
from . import views

app_name = 'monitoring'

urlpatterns = [
    # Monitoring task management
    path('tasks/',                       views.MonitoringTaskListView.as_view(),      name='task-list'),
    path('tasks/<int:pk>/',              views.MonitoringTaskDetailView.as_view(),    name='task-detail'),
    path('tasks/<int:pk>/run/',          views.RunMonitoringTaskView.as_view(),       name='run-task'),

    # Monitoring reports and execution logs
    path('reports/',                     views.MonitoringReportListView.as_view(),    name='report-list'),
    path('reports/<int:pk>/',            views.MonitoringReportDetailView.as_view(),  name='report-detail'),

    # System health and statistics
    path('health/',                      views.SystemHealthView.as_view(),            name='health'),
    path('stats/',                       views.MonitoringStatsView.as_view(),         name='stats'),
]
