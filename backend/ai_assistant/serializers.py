from rest_framework import serializers
from .models import Conversation, Message, AIConfiguration


class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ('id', 'role', 'content', 'timestamp', 'tokens_used')
        read_only_fields = ('id', 'timestamp', 'tokens_used')


class ConversationSerializer(serializers.ModelSerializer):
    messages = MessageSerializer(many=True, read_only=True)
    message_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Conversation
        fields = ('id', 'title', 'created_at', 'updated_at', 'messages', 'message_count')
        read_only_fields = ('id', 'created_at', 'updated_at')
    
    def get_message_count(self, obj):
        return obj.messages.count()


class ConversationListSerializer(serializers.ModelSerializer):
    """Lighter serializer for listing conversations without messages"""
    message_count = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    
    class Meta:
        model = Conversation
        fields = ('id', 'title', 'created_at', 'updated_at', 'message_count', 'last_message')
        read_only_fields = ('id', 'created_at', 'updated_at')
    
    def get_message_count(self, obj):
        return obj.messages.count()
    
    def get_last_message(self, obj):
        last = obj.messages.last()
        if last:
            return {
                'role': last.role,
                'content': last.content[:100],
                'timestamp': last.timestamp
            }
        return None


class SendMessageSerializer(serializers.Serializer):
    message = serializers.CharField(required=True, max_length=5000)
