from django.urls import path
from .views import (
    ConversationListCreateView,
    ConversationDetailView,
    SendMessageView,
    AIConfigStatusView
)

urlpatterns = [
    path('conversations/', ConversationListCreateView.as_view(), name='conversation-list'),
    path('conversations/<int:pk>/', ConversationDetailView.as_view(), name='conversation-detail'),
    path('conversations/<int:pk>/send/', SendMessageView.as_view(), name='send-message'),
    path('status/', AIConfigStatusView.as_view(), name='ai-status'),
]
