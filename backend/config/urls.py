from django.contrib import admin
from django.urls import path, include


urlpatterns = [

    # Django admin panel
    path('admin/', admin.site.urls),

    # All our API endpoints live under /api/
    # include() tells Django to look inside the specified urls.py file
    # for more URL patterns whenever the path starts with that prefix.
    path('api/users/',      include('users.urls',                          namespace='users')),
    path('api/devices/',    include('devices.urls',                        namespace='devices')),
    path('api/metrics/',    include('metrics.urls',                        namespace='metrics')),
    path('api/alerts/',     include('alerts.urls',                         namespace='alerts')),
    path('api/monitoring/', include('monitoring.urls',                     namespace='monitoring')),
    path('api/dashboard/',  include('monitoring.dashboard_urls')),
    path('api/organisations/', include('organisations.urls',              namespace='organisations')),

    # Invitation accept/decline (token-based, user-scoped)
    path('api/invitations/',                include('organisations.invitation_urls')),
    
    # AI Assistant
    path('api/ai/', include('ai_assistant.urls')),
]