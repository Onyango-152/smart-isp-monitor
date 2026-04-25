from django.db import models
from django.contrib.auth import get_user_model
from django.core.validators import MinLengthValidator

User = get_user_model()


class AIConfiguration(models.Model):
    """
    Stores AI provider configuration (API keys, models, etc.)
    Managed via Django admin panel.
    """
    PROVIDER_CHOICES = [
        ('gemini', 'Google Gemini'),
        ('openai', 'OpenAI'),
        ('anthropic', 'Anthropic Claude'),
    ]
    
    name = models.CharField(max_length=100, unique=True)
    provider = models.CharField(max_length=20, choices=PROVIDER_CHOICES, default='gemini')
    api_key = models.CharField(max_length=500, validators=[MinLengthValidator(10)])
    model_name = models.CharField(max_length=100, default='gemini-pro')
    is_active = models.BooleanField(default=True)
    max_tokens = models.IntegerField(default=2048)
    temperature = models.FloatField(default=0.7)
    system_prompt = models.TextField(
        blank=True,
        default="You are a helpful ISP network monitoring assistant. "
                "Help users understand their network metrics, diagnose issues, "
                "and provide actionable recommendations."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'AI Configuration'
        verbose_name_plural = 'AI Configurations'
        ordering = ['-is_active', 'name']
    
    def __str__(self):
        return f"{self.name} ({self.provider})"


class Conversation(models.Model):
    """
    Represents a conversation thread between a user and the AI assistant.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ai_conversations')
    title = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Conversation'
        verbose_name_plural = 'Conversations'
        ordering = ['-updated_at']
    
    def __str__(self):
        return f"{self.user.username} - {self.title or 'Untitled'} ({self.created_at.strftime('%Y-%m-%d')})"


class Message(models.Model):
    """
    Individual messages within a conversation.
    """
    ROLE_CHOICES = [
        ('user', 'User'),
        ('assistant', 'Assistant'),
        ('system', 'System'),
    ]
    
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    tokens_used = models.IntegerField(null=True, blank=True)
    
    class Meta:
        verbose_name = 'Message'
        verbose_name_plural = 'Messages'
        ordering = ['timestamp']
    
    def __str__(self):
        preview = self.content[:50] + '...' if len(self.content) > 50 else self.content
        return f"{self.role}: {preview}"
