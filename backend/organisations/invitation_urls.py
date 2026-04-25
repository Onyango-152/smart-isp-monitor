from django.urls import path
from . import views

urlpatterns = [
    path('',                           views.MyInvitationsView.as_view(),    name='my-invitations'),
    path('<int:pk>/accept/',           views.AcceptInvitationView.as_view(), name='invitation-accept'),
    path('<int:pk>/decline/',          views.DeclineInvitationView.as_view(),name='invitation-decline'),
    # Token-based links from email (unauthenticated flow kept for email links)
    path('<str:token>/accept/',        views.AcceptInvitationView.as_view(), name='invitation-accept-token'),
    path('<str:token>/decline/',       views.DeclineInvitationView.as_view(),name='invitation-decline-token'),
]
