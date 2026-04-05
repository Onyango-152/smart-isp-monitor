from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

app_name = 'users'

urlpatterns = [
    # Authentication endpoints — these are public (no token needed)
    path('register/',        views.RegisterView.as_view(),       name='register'),
    path('login/',           views.LoginView.as_view(),          name='login'),
    path('logout/',          views.LogoutView.as_view(),         name='logout'),
    path('verify-email/',    views.VerifyEmailView.as_view(),    name='verify-email'),
    path('resend-otp/',      views.ResendOtpView.as_view(),      name='resend-otp'),

    # TokenRefreshView comes from simplejwt — it accepts a refresh token
    # and returns a new access token. The Flutter app calls this
    # automatically when the access token expires.
    path('token/refresh/',   TokenRefreshView.as_view(),         name='token-refresh'),

    # Profile endpoints — these require authentication
    path('profile/',         views.ProfileView.as_view(),        name='profile'),
    path('change-password/', views.ChangePasswordView.as_view(), name='change-password'),

    # Manager/admin: list all customer accounts
    path('clients/',         views.ClientListView.as_view(),     name='client-list'),

    # Admin only
    path('',                 views.UserListView.as_view(),       name='user-list'),
]
