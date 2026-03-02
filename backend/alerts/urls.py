from django.urls import path
from . import views

# app_name creates a namespace for these URLs.
# This means you can refer to them as 'alerts:list' elsewhere in the
# project which avoids naming conflicts if two apps have a URL
# with the same name.
app_name = 'alerts'

urlpatterns = [

    # Alert management endpoints
    path('list/',                 views.AlertListView.as_view(),           name='alert-list'),
    path('<int:pk>/',             views.AlertDetailView.as_view(),         name='alert-detail'),
    path('<int:pk>/acknowledge/', views.AcknowledgeAlertView.as_view(),    name='acknowledge-alert'),
    path('<int:pk>/resolve/',     views.ResolveAlertView.as_view(),        name='resolve-alert'),

    # Alert rule management
    path('rules/',                views.AlertRuleListView.as_view(),       name='rule-list'),
    path('rules/<int:pk>/',       views.AlertRuleDetailView.as_view(),     name='rule-detail'),

    # Notification channels
    path('channels/',             views.NotificationChannelListView.as_view(), name='channel-list'),
    path('channels/<int:pk>/',    views.NotificationChannelDetailView.as_view(), name='channel-detail'),
]