from django.urls import path
from . import views

# Mounted at /api/dashboard/ from config/urls.py
urlpatterns = [
    path('summary/',  views.DashboardSummaryView.as_view(),  name='dashboard-summary'),
    path('customer/', views.CustomerDashboardView.as_view(), name='dashboard-customer'),
]
