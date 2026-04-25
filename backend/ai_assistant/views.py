from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404

from .models import Conversation, Message
from .serializers import (
    ConversationSerializer,
    ConversationListSerializer,
    MessageSerializer,
    SendMessageSerializer
)
from .services import AIService


class ConversationListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/ai/conversations/ - List user's conversations
    POST /api/ai/conversations/ - Create new conversation
    """
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.request.method == 'GET':
            return ConversationListSerializer
        return ConversationSerializer
    
    def get_queryset(self):
        return Conversation.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ConversationDetailView(generics.RetrieveDestroyAPIView):
    """
    GET    /api/ai/conversations/<id>/ - Get conversation with messages
    DELETE /api/ai/conversations/<id>/ - Delete conversation
    """
    permission_classes = [IsAuthenticated]
    serializer_class = ConversationSerializer
    
    def get_queryset(self):
        return Conversation.objects.filter(user=self.request.user)


class SendMessageView(APIView):
    """
    POST /api/ai/conversations/<id>/send/
    Send a message and get AI response
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request, pk):
        conversation = get_object_or_404(
            Conversation,
            pk=pk,
            user=request.user
        )
        
        serializer = SendMessageSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        user_message = serializer.validated_data['message']
        
        try:
            response_text = AIService.send_message(conversation, user_message)
            
            # Return the updated conversation
            conv_serializer = ConversationSerializer(conversation)
            return Response(conv_serializer.data, status=status.HTTP_200_OK)
            
        except ValueError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return Response(
                {'error': f'AI service error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AIConfigStatusView(APIView):
    """
    GET /api/ai/status/
    Check if AI is configured and ready
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        config = AIService.get_active_config()
        if config:
            return Response({
                'configured': True,
                'provider': config.provider,
                'model': config.model_name
            })
        return Response({
            'configured': False,
            'message': 'No active AI configuration found'
        })
