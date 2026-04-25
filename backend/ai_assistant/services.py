"""
AI Assistant service layer for handling Gemini API interactions.
"""
import google.generativeai as genai
from typing import List, Dict, Optional
from .models import AIConfiguration, Conversation, Message


class AIService:
    """Service for interacting with AI providers (Gemini, etc.)"""
    
    @staticmethod
    def get_active_config() -> Optional[AIConfiguration]:
        """Get the active AI configuration"""
        return AIConfiguration.objects.filter(is_active=True).first()
    
    @staticmethod
    def configure_gemini(config: AIConfiguration):
        """Configure Gemini with API key"""
        genai.configure(api_key=config.api_key)
    
    @staticmethod
    def send_message(conversation: Conversation, user_message: str) -> str:
        """
        Send a message to the AI and get a response.
        
        Args:
            conversation: The conversation object
            user_message: The user's message text
            
        Returns:
            The AI's response text
        """
        config = AIService.get_active_config()
        if not config:
            raise ValueError("No active AI configuration found. Please configure AI in admin panel.")
        
        # Save user message
        Message.objects.create(
            conversation=conversation,
            role='user',
            content=user_message
        )
        
        # Configure AI provider
        if config.provider == 'gemini':
            AIService.configure_gemini(config)
            response_text = AIService._send_gemini_message(config, conversation, user_message)
        else:
            raise ValueError(f"Provider {config.provider} not yet implemented")
        
        # Save assistant response
        Message.objects.create(
            conversation=conversation,
            role='assistant',
            content=response_text
        )
        
        # Update conversation title if it's the first message
        if conversation.messages.count() == 2 and not conversation.title:
            conversation.title = user_message[:100]
            conversation.save()
        
        return response_text
    
    @staticmethod
    def _send_gemini_message(config: AIConfiguration, conversation: Conversation, user_message: str) -> str:
        """Send message to Gemini API"""
        # Get conversation history (excluding the just-added user message)
        all_messages = list(conversation.messages.exclude(role='system').order_by('timestamp'))
        
        # Build history excluding the last message (the one we just added)
        history = []
        if len(all_messages) > 1:
            for msg in all_messages[:-1]:
                history.append({
                    'role': 'user' if msg.role == 'user' else 'model',
                    'parts': [msg.content]
                })
        
        # Create model
        model = genai.GenerativeModel(
            model_name=config.model_name,
            generation_config={
                'temperature': config.temperature,
                'max_output_tokens': config.max_tokens,
            }
        )
        
        # Start chat with history
        chat = model.start_chat(history=history)
        
        # Send message
        response = chat.send_message(user_message)
        
        return response.text
    
    @staticmethod
    def get_conversation_history(conversation: Conversation) -> List[Dict[str, str]]:
        """Get formatted conversation history"""
        messages = conversation.messages.all()
        return [
            {
                'role': msg.role,
                'content': msg.content,
                'timestamp': msg.timestamp.isoformat()
            }
            for msg in messages
        ]
