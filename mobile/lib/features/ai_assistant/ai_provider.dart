import 'package:flutter/material.dart';
import '../../services/api_client.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.role,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AIAssistantProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;
  String? _errorMessage;
  int? _conversationId;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _conversationId != null;

  AIAssistantProvider() {
    _initializeConversation();
  }

  Future<void> _initializeConversation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if AI is configured
      final status = await ApiClient.getAIStatus();
      if (status['configured'] != true) {
        _errorMessage = 'AI Assistant is not configured. Please contact support.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Create a new conversation
      final conversation = await ApiClient.createAIConversation(
          title: 'Help Session ${DateTime.now().toString().substring(0, 16)}');
      _conversationId = conversation['id'] as int;

      // Add greeting message
      _messages.add(ChatMessage(
        role: MessageRole.assistant,
        text:
            'Hi! I\'m your ISP Help Assistant 👋\n\nI can help you troubleshoot internet problems, explain your network metrics, and answer questions about your service. Just ask me anything!',
      ));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize AI Assistant: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_conversationId == null) {
      _errorMessage = 'No active conversation. Please restart the assistant.';
      notifyListeners();
      return;
    }

    // Add user message
    _messages.add(ChatMessage(role: MessageRole.user, text: text.trim()));
    _isTyping = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Send message to API and get response
      final response =
          await ApiClient.sendAIMessage(_conversationId!, text.trim());

      // Extract the latest assistant message from the response
      final messages = response['messages'] as List<dynamic>;
      final lastMessage = messages.last as Map<String, dynamic>;

      if (lastMessage['role'] == 'assistant') {
        _messages.add(ChatMessage(
          role: MessageRole.assistant,
          text: lastMessage['content'] as String,
          timestamp: DateTime.parse(lastMessage['timestamp'] as String),
        ));
      }
    } catch (e) {
      _errorMessage = 'Failed to send message: ${e.toString()}';
      // Add error message to chat
      _messages.add(ChatMessage(
        role: MessageRole.assistant,
        text:
            'Sorry, I encountered an error. Please try again or contact support if the problem persists.',
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  Future<void> resetConversation() async {
    if (_conversationId != null) {
      try {
        await ApiClient.deleteAIConversation(_conversationId!);
      } catch (_) {
        // Ignore deletion errors
      }
    }
    _messages.clear();
    _conversationId = null;
    _errorMessage = null;
    await _initializeConversation();
  }
}
