import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import 'ai_provider.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late AIAssistantProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = AIAssistantProvider();
    _provider.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _provider.removeListener(_scrollToBottom);
    _provider.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<AIAssistantProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
            appBar: _buildAppBar(provider),
            body: Column(
              children: [
                Expanded(child: _buildMessageList(provider)),
                if (provider.errorMessage != null)
                  _buildErrorBanner(provider),
                _buildInputBar(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AIAssistantProvider provider) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Assistant',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Text('Powered by Gemini',
              style: TextStyle(fontSize: 10.5, color: Colors.white70)),
        ],
      ),
      actions: [
        if (provider.isConfigured)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Conversation'),
                  content: const Text(
                      'Start a new conversation? Current chat will be deleted.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        provider.resetConversation();
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMessageList(AIAssistantProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing AI Assistant...'),
          ],
        ),
      );
    }

    if (!provider.isConfigured && provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => provider.resetConversation(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: provider.messages.length + (provider.isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == provider.messages.length) {
          return _buildTypingIndicator();
        }
        final message = provider.messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser 
              ? (isDark ? AppColors.primaryLight : AppColors.primary)
              : (isDark ? AppColors.darkSurfaceVariant : Colors.grey[200]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser 
                ? (isDark ? AppColors.darkBackground : Colors.white)
                : (isDark ? AppColors.darkTextPrimary : Colors.black87),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value - delay).clamp(0.0, 1.0);
        return Opacity(
          opacity: 0.3 + (animValue * 0.7),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkTextSecondary : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(AIAssistantProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red[100],
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AIAssistantProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: provider.isConfigured && !provider.isTyping,
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  provider.sendMessage(text);
                  _controller.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            child: IconButton(
              icon: Icon(
                Icons.send_rounded, 
                color: isDark ? AppColors.darkBackground : Colors.white,
              ),
              onPressed: provider.isConfigured && !provider.isTyping
                  ? () {
                      final text = _controller.text;
                      if (text.trim().isNotEmpty) {
                        provider.sendMessage(text);
                        _controller.clear();
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
