import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a chat message
// ─────────────────────────────────────────────────────────────────────────────

enum MessageRole { user, assistant }

class ChatMessage {
  final String      text;
  final MessageRole role;
  final DateTime    timestamp;
  final List<_SuggestedQuestion>? suggestions; // assistant can attach follow-ups
  final _TroubleshootGuide? guide;             // assistant can attach a step guide

  ChatMessage({
    required this.text,
    required this.role,
    this.suggestions,
    this.guide,
  }) : timestamp = DateTime.now();
}

class _SuggestedQuestion {
  final String label;
  final String query;
  const _SuggestedQuestion(this.label, this.query);
}

class _TroubleshootGuide {
  final String       title;
  final List<String> steps;
  const _TroubleshootGuide({required this.title, required this.steps});
}

// ─────────────────────────────────────────────────────────────────────────────
// HelpAssistantProvider — the brain of the chat
// ─────────────────────────────────────────────────────────────────────────────

class HelpAssistantProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  List<ChatMessage> get messages  => List.unmodifiable(_messages);
  bool              get isTyping  => _isTyping;

  HelpAssistantProvider() {
    // Greeting message on first load
    _messages.add(ChatMessage(
      role: MessageRole.assistant,
      text: 'Hi! I\'m your ISP Help Assistant 👋\n\nI can help you troubleshoot common internet problems at home. Just ask me anything — in plain language, no technical knowledge needed.',
      suggestions: const [
        _SuggestedQuestion('My internet is not working', 'My internet is not working'),
        _SuggestedQuestion('Router is blinking red', 'Why is my router blinking red?'),
        _SuggestedQuestion('Slow internet', 'My internet is very slow'),
        _SuggestedQuestion('Wi-Fi drops frequently', 'My Wi-Fi keeps disconnecting'),
      ],
    ));
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    _messages.add(ChatMessage(role: MessageRole.user, text: text.trim()));
    _isTyping = true;
    notifyListeners();

    // Simulate realistic typing delay (600ms – 1.4s)
    await Future.delayed(Duration(milliseconds: 600 + (text.length * 10).clamp(0, 800)));

    // Generate response
    final response = _generateResponse(text.trim().toLowerCase());
    _messages.add(response);
    _isTyping = false;
    notifyListeners();
  }

  // ── Knowledge base: pattern matching → guided response ───────────────────

  ChatMessage _generateResponse(String q) {

    // ── Router offline / not working ─────────────────────────────────────────
    if (_matches(q, ['router offline', 'router not working', 'router off', 'router dead',
                     'no internet', 'internet not working', 'internet is down',
                     'cannot connect', 'no connection', 'not connecting'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'That sounds like your router might be offline. Don\'t worry — this is one of the most common issues and is usually easy to fix at home.',
        guide: const _TroubleshootGuide(
          title: '🔌 Router Offline — Step-by-Step Fix',
          steps: [
            'Look at your router. Are any lights on? If there are NO lights at all, check that the power cable is firmly plugged into both the router and the wall socket.',
            'If the router has lights but no internet, find the POWER button on the back and press it once to turn it off. Wait 30 seconds — this allows the device to fully reset.',
            'Press the POWER button again to turn it back on. Wait 2 full minutes for it to fully restart and connect.',
            'Try opening a website on your phone or laptop. If it works, you\'re done!',
            'If it still doesn\'t work after 2 attempts, the issue may be on our network side. Our monitoring system will have already detected this and a technician will be in touch.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('Lights are on but no internet', 'Router has lights but no internet'),
          _SuggestedQuestion('How do I restart my router?', 'How do I restart my router?'),
          _SuggestedQuestion('Still not working after restart', 'Internet still not working after restarting router'),
        ],
      );
    }

    // ── Blinking red / red light ──────────────────────────────────────────────
    if (_matches(q, ['blinking red', 'red light', 'flashing red', 'red blink',
                     'red led', 'router red', 'light is red'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'A red blinking light on your router is the device\'s way of saying "I need help!" Here\'s what the different red lights usually mean and what to do:',
        guide: const _TroubleshootGuide(
          title: '🔴 Red Light on Router — What It Means',
          steps: [
            'POWER light is red → The router is overheating or has a hardware fault. Make sure it is in a well-ventilated spot, not inside a box or cabinet. Turn it off for 5 minutes to cool down, then turn it back on.',
            'INTERNET / WAN light is red → The router cannot reach the internet. This is usually a connection from your ISP to the router. Try restarting the router first (hold power off for 30 seconds, then on). If the red light returns, it is likely an issue on the line — contact support.',
            'Wi-Fi light is red → The wireless radio in the router has a problem. Try restarting the router. If the light stays red, the wireless hardware may need replacement.',
            'All lights red → This often means a firmware crash. Hold the RESET button on the back of the router for 10 seconds using a pin or paperclip. This will reset the router to factory settings — it will reconnect automatically.',
            'If you are unsure which light is which, check the label on the bottom of your router — it usually shows what each LED means.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('All lights are red', 'All lights on my router are red'),
          _SuggestedQuestion('Only the internet light is red', 'Only the internet light is red'),
          _SuggestedQuestion('How to reset my router', 'How do I reset my router to factory settings?'),
        ],
      );
    }

    // ── Slow internet ─────────────────────────────────────────────────────────
    if (_matches(q, ['slow internet', 'slow connection', 'slow speed', 'internet is slow',
                     'bad speed', 'low speed', 'internet slow', 'poor speed', 'lagging',
                     'buffering', 'video freezing', 'takes long to load'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'Slow internet is frustrating! There are several things that can cause it, and most can be fixed at home without a technician. Let\'s work through them:',
        guide: const _TroubleshootGuide(
          title: '🐢 Slow Internet — How to Improve It',
          steps: [
            'First, check how many devices are connected to your Wi-Fi. Too many active devices sharing the connection at once (streaming, downloading, video calls) will slow everyone down.',
            'Restart your router — turn it off, wait 30 seconds, then turn it back on. This clears the router\'s memory and often speeds things up significantly.',
            'Move closer to your router if you are using Wi-Fi. Walls, floors, and other electronics (especially microwaves) can weaken the signal. The further you are, the slower the connection.',
            'Check if anyone is downloading large files or streaming in high quality (e.g. 4K video). Pause these to free up bandwidth for other tasks.',
            'If only one device is slow, the issue is likely with that device, not the internet. Restart the device and check its Wi-Fi signal.',
            'Run a speed test: open your browser and go to fast.com. This will show your current download speed. Share the result with our support team if needed.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('Speed test shows low speeds', 'Speed test shows low speeds'),
          _SuggestedQuestion('Only one device is slow', 'Only my phone is slow but laptop is fine'),
          _SuggestedQuestion('Internet slow at certain times', 'Internet is slow in the evening'),
        ],
      );
    }

    // ── Wi-Fi dropping / disconnecting ────────────────────────────────────────
    if (_matches(q, ['disconnecting', 'drops', 'keeps dropping', 'wifi drops',
                     'disconnects', 'keeps disconnecting', 'unstable', 'wifi cutting',
                     'loses connection', 'random disconnect'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'Frequent disconnections are usually caused by a few common things — interference, overheating, or a router that needs a restart. Let\'s troubleshoot:',
        guide: const _TroubleshootGuide(
          title: '📶 Wi-Fi Keeps Dropping — Fix Steps',
          steps: [
            'Restart your router: power it off, wait 30 seconds, power it back on. Many routers develop memory issues over time if left on for weeks without a restart.',
            'Check the router\'s location. It should be in an open, elevated spot (like a shelf). Keep it away from cordless phones, baby monitors, and microwaves — all of these use similar radio frequencies and can interfere.',
            'Check if the router is hot to the touch. If it is very warm, place it somewhere with better airflow. Overheating causes routers to disconnect devices to protect themselves.',
            'If only one device keeps disconnecting, forget the Wi-Fi network on that device and reconnect from scratch: Settings → Wi-Fi → Select your network → Forget → Reconnect and re-enter the password.',
            'If all devices disconnect at the same time, the issue is likely the internet line rather than Wi-Fi. Check if the WAN/Internet light on the router goes off when the disconnection happens.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('Only my phone disconnects', 'Only my phone keeps disconnecting from Wi-Fi'),
          _SuggestedQuestion('All devices disconnect together', 'All devices lose internet at the same time'),
          _SuggestedQuestion('Router overheating', 'My router feels very hot'),
        ],
      );
    }

    // ── Cannot connect to Wi-Fi ───────────────────────────────────────────────
    if (_matches(q, ['cannot connect to wifi', 'cant connect wifi', 'wifi not connecting',
                     'wrong password', 'incorrect password', 'password not working',
                     'wifi not showing', 'cannot find wifi', 'network not found'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'Can\'t connect to Wi-Fi? This is usually a password issue or the device needs to forget and re-learn the network. Here\'s how to fix it:',
        guide: const _TroubleshootGuide(
          title: '🔑 Cannot Connect to Wi-Fi — Fix Steps',
          steps: [
            'Make sure you are entering the correct Wi-Fi password. It is case-sensitive — uppercase and lowercase letters matter. The password is usually printed on a label on the bottom or back of your router.',
            'If you have changed the password recently, all devices need to be reconnected with the new password. On your device go to Settings → Wi-Fi, tap the network name, choose "Forget" then reconnect.',
            'If the Wi-Fi network does not appear in the list at all: restart your router AND the device you are trying to connect. Wait 2 minutes and check again.',
            'Make sure your device\'s Wi-Fi is actually turned on — it\'s easy to accidentally have it switched off in quick settings.',
            'Check if the router\'s Wi-Fi light is on. If the Wi-Fi light is off or red, the wireless radio may have turned off — restarting the router usually fixes this.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('What is my Wi-Fi password?', 'Where do I find my Wi-Fi password?'),
          _SuggestedQuestion('Wi-Fi not showing up at all', 'My Wi-Fi network is not showing in the list'),
          _SuggestedQuestion('Forgot the Wi-Fi password', 'I forgot my Wi-Fi password'),
        ],
      );
    }

    // ── Find Wi-Fi password ───────────────────────────────────────────────────
    if (_matches(q, ['wifi password', 'wi-fi password', 'password', 'find password',
                     'where is password', 'what is the password', 'forgot password'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'Here\'s how to find your Wi-Fi password — there are a few places to check:',
        guide: const _TroubleshootGuide(
          title: '🔑 Finding Your Wi-Fi Password',
          steps: [
            'Check the label on your router: flip it over or look at the back/bottom. There is usually a sticker showing the Wi-Fi name (SSID) and the default password (sometimes labelled "WPA Key", "Security Key", or "Wi-Fi Password").',
            'If you changed the password yourself and forgot it: on a Windows PC that is already connected, go to Settings → Network & Internet → Wi-Fi → click your network name → "Show password". On a Mac: open Keychain Access, search for your Wi-Fi name, tick "Show Password".',
            'On Android: Settings → Wi-Fi → tap the connected network → there is usually a QR code and a "Share" option that reveals the password.',
            'If all else fails, you can reset the router to factory settings (hold the reset button for 10 seconds), which restores the original password on the label.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('How to reset my router', 'How do I reset my router?'),
          _SuggestedQuestion('Change my Wi-Fi password', 'How do I change my Wi-Fi password?'),
        ],
      );
    }

    // ── Router overheating ────────────────────────────────────────────────────
    if (_matches(q, ['overheating', 'too hot', 'very hot', 'router hot', 'router warm',
                     'feels hot', 'heating up'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'A hot router is a common and fixable problem. Overheating causes slowdowns, disconnections, and even hardware damage over time. Here\'s what to do:',
        guide: const _TroubleshootGuide(
          title: '🌡️ Router Overheating — What To Do',
          steps: [
            'Turn the router off immediately if it is very hot to the touch. Let it cool for 10–15 minutes.',
            'Move the router to an open, well-ventilated location. A shelf or on top of furniture works well. Never place it inside a closed cabinet, box, or drawer.',
            'Keep it away from direct sunlight and other heat-producing electronics like TVs and decoders.',
            'Make sure nothing is sitting on top of the router — books, remotes, or other items block the vents on top.',
            'Routers should be restarted at least once a week. Like any computer, they need a fresh start. If overheating is frequent, ask our support team about a hardware replacement.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('Router keeps restarting on its own', 'Router restarts by itself randomly'),
          _SuggestedQuestion('Request hardware replacement', 'How do I request a new router?'),
        ],
      );
    }

    // ── How to restart router ─────────────────────────────────────────────────
    if (_matches(q, ['how to restart', 'restart router', 'reboot router', 'power cycle',
                     'restart my router', 'reboot my router'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'Restarting a router is simple and is the first fix for most internet problems. Here is the correct way to do it:',
        guide: const _TroubleshootGuide(
          title: '🔄 How To Correctly Restart Your Router',
          steps: [
            'Find the POWER button on the back or side of your router. Press it once to turn the router OFF. Alternatively, you can unplug the power cable from the wall socket.',
            'IMPORTANT: wait a full 30 seconds. This allows the router\'s memory to fully clear. Many people skip this step and plug it back in too early.',
            'Press the POWER button again to turn the router back ON, or plug the power cable back in.',
            'Wait 2 full minutes. The router needs time to start up and reconnect to the internet. The lights will blink and then settle — this is normal.',
            'Test your connection by opening a website or app. If it works, you\'re done!',
            'Tip: restarting your router once a week (ideally late at night when you\'re not using it) keeps it running smoothly and prevents many common issues.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('Internet still not working after restart', 'Internet still not working after restarting'),
          _SuggestedQuestion('How often should I restart my router?', 'How often should I restart my router?'),
        ],
      );
    }

    // ── Ethernet / cable connection ───────────────────────────────────────────
    if (_matches(q, ['ethernet', 'cable', 'wired', 'lan port', 'lan cable',
                     'plugged in', 'yellow port', 'lan not working'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'Issues with a wired (Ethernet/LAN) connection are usually caused by the cable itself or the port. Here\'s how to check:',
        guide: const _TroubleshootGuide(
          title: '🔌 Wired Connection Problems — Fix Steps',
          steps: [
            'Check the cable at both ends — where it plugs into the router AND where it plugs into your computer. Push both ends in firmly until you hear or feel a click.',
            'Look at the LAN light on the router when the cable is connected. If there is NO light next to that port, the cable may be faulty — try a different cable if you have one.',
            'Try a different LAN port on the router. Routers usually have 4 ports — if one is faulty, another may work.',
            'If your computer shows "Ethernet Connected" but still has no internet, restart both the router and the computer.',
            'Make sure the Ethernet adapter on your computer is enabled: on Windows, go to Settings → Network → Ethernet and ensure it is turned on.',
          ],
        ),
        suggestions: const [
          _SuggestedQuestion('Ethernet light is not on', 'The LAN light on my router is not lighting up'),
          _SuggestedQuestion('Connected by cable but no internet', 'Cable is plugged in but no internet'),
        ],
      );
    }

    // ── Report a fault ────────────────────────────────────────────────────────
    if (_matches(q, ['report', 'complain', 'report fault', 'report problem',
                     'call support', 'contact support', 'speak to someone', 'human',
                     'technician', 'send technician'])) {
      return ChatMessage(
        role: MessageRole.assistant,
        text: 'Of course! You can report an issue directly through the app and a technician will follow up:\n\n1. Go to the **My Service** tab (first tab below)\n2. Tap the **"Report Issue"** button\n3. Describe what is happening in your own words\n4. Our team will receive it and respond as soon as possible.\n\nFor urgent issues, our monitoring system continuously watches your connection — if we detect a problem, our team is notified automatically even before you report it.',
        suggestions: const [
          _SuggestedQuestion('How long does it take to fix?', 'How long does a technician take to fix an issue?'),
          _SuggestedQuestion('Track my reported issue', 'How do I track a reported issue?'),
        ],
      );
    }

    // ── No specific match — friendly fallback ─────────────────────────────────
    return ChatMessage(
      role: MessageRole.assistant,
      text: 'I want to help! I didn\'t quite catch that — could you try rephrasing your question? You can also choose from the common issues below, or tap "Report Issue" on the My Service screen to reach our support team.',
      suggestions: const [
        _SuggestedQuestion('No internet', 'My internet is not working'),
        _SuggestedQuestion('Router light problem', 'Why is my router blinking red?'),
        _SuggestedQuestion('Slow internet', 'My internet is very slow'),
        _SuggestedQuestion('Can\'t connect', 'Cannot connect to Wi-Fi'),
        _SuggestedQuestion('Contact support', 'I want to speak to someone'),
      ],
    );
  }

  bool _matches(String query, List<String> keywords) {
    for (final k in keywords) {
      if (query.contains(k)) return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HelpAssistantScreen
// ─────────────────────────────────────────────────────────────────────────────

class HelpAssistantScreen extends StatefulWidget {
  const HelpAssistantScreen({super.key});

  @override
  State<HelpAssistantScreen> createState() => _HelpAssistantScreenState();
}

class _HelpAssistantScreenState extends State<HelpAssistantScreen> {
  final TextEditingController _controller  = TextEditingController();
  final ScrollController      _scroll      = ScrollController();
  late HelpAssistantProvider  _provider;

  @override
  void initState() {
    super.initState();
    _provider = HelpAssistantProvider();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  void _send([String? text]) {
    final msg = (text ?? _controller.text).trim();
    if (msg.isEmpty) return;
    _controller.clear();
    _provider.sendMessage(msg);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<HelpAssistantProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Container(
                    width:  36, height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.support_agent, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Help Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Always available', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon:    const Icon(Icons.refresh),
                  tooltip: 'New conversation',
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title:   const Text('Start Over?'),
                        content: const Text('This will clear the current conversation.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                _provider.removeListener(_scrollToBottom);
                                _provider.dispose();
                                _provider = HelpAssistantProvider();
                                _provider.addListener(_scrollToBottom);
                              });
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // ── Message list ─────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: provider.messages.length + (provider.isTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (provider.isTyping && i == provider.messages.length) {
                        return _TypingBubble();
                      }
                      final msg = provider.messages[i];
                      return _MessageBubble(message: msg, onSuggestion: _send);
                    },
                  ),
                ),

                // ── Input bar ────────────────────────────────────────────
                _buildInputBar(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(HelpAssistantProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              maxLines:   4,
              minLines:   1,
              decoration: InputDecoration(
                hintText:     'Ask me anything about your internet...',
                hintStyle:    TextStyle(color: AppColors.textHintOf(context)),
                filled:       true,
                fillColor:    AppColors.bg(context),
                border:       OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:   BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color:        provider.isTyping ? AppColors.textHint : AppColors.primary,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: provider.isTyping ? null : _send,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child:   Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageBubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage                    message;
  final void Function(String) onSuggestion;
  const _MessageBubble({required this.message, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ── Bubble ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width:  32, height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent, color: Colors.white, size: 18),
                ),
              ],
              Flexible(
                child: Container(
                  padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color:  isUser ? Colors.white : AppColors.textPrimaryOf(context),
                      fontSize: 14, height: 1.5,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                Container(
                  width:  32, height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurfaceOf(context), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: AppColors.primary, size: 18),
                ),
              ],
            ],
          ),

          // ── Troubleshoot guide ───────────────────────────────────────────
          if (message.guide != null) ...[
            const SizedBox(height: 8),
            _TroubleshootCard(guide: message.guide!),
          ],

          // ── Suggested questions ──────────────────────────────────────────
          if (message.suggestions != null && message.suggestions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.suggestions!.map((s) => _SuggestionChip(
                  label: s.label,
                  onTap: () => onSuggestion(s.query),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Troubleshoot step-by-step card ────────────────────────────────────────────

class _TroubleshootCard extends StatefulWidget {
  final _TroubleshootGuide guide;
  const _TroubleshootCard({required this.guide});

  @override
  State<_TroubleshootCard> createState() => _TroubleshootCardState();
}

class _TroubleshootCardState extends State<_TroubleshootCard> {
  int _completedSteps = 0;

  @override
  Widget build(BuildContext context) {
    final steps = widget.guide.steps;
    return Container(
      margin:  const EdgeInsets.only(left: 40),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Icon(Icons.checklist_rtl, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.guide.title, style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress
          if (_completedSteps > 0)
            Text(
              '$_completedSteps of ${steps.length} steps done',
              style: const TextStyle(fontSize: 11, color: AppColors.primaryLight),
            ),
          const SizedBox(height: 10),

          // Steps
          ...steps.asMap().entries.map((entry) {
            final idx       = entry.key;
            final step      = entry.value;
            final done      = idx < _completedSteps;
            final isCurrent = idx == _completedSteps;
            return _StepRow(
              number:    idx + 1,
              text:      step,
              isDone:    done,
              isCurrent: isCurrent,
              onDone:    done ? null : () => setState(() {
                if (isCurrent) _completedSteps++;
              }),
            );
          }),

          // Reset button
          if (_completedSteps > 0) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _completedSteps = 0),
              icon:  const Icon(Icons.replay, size: 14),
              label: const Text('Start over', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int        number;
  final String     text;
  final bool       isDone;
  final bool       isCurrent;
  final VoidCallback? onDone;

  const _StepRow({
    required this.number,
    required this.text,
    required this.isDone,
    required this.isCurrent,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number / check circle
          GestureDetector(
            onTap: onDone,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width:  26, height: 26,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.online
                    : isCurrent ? AppColors.primary : AppColors.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? AppColors.online : isCurrent ? AppColors.primary : AppColors.primaryLight,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text('$number', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : AppColors.primaryLight,
                      )),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize:  13,
                    height:    1.5,
                    color:     isDone ? AppColors.textHintOf(context) : AppColors.textPrimaryOf(context),
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (isCurrent && onDone != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color:        AppColors.online,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Mark done ✓', style: TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:        AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(
              fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.support_agent, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:        AppColors.surfaceOf(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final delay = i * 0.33;
                  final opacity = ((_controller.value - delay).clamp(0.0, 1.0) +
                      (1.0 - (_controller.value - delay).clamp(0.0, 1.0) * 2.0).clamp(0.3, 1.0)) / 2;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Opacity(
                      opacity: opacity.clamp(0.3, 1.0),
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight, shape: BoxShape.circle),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
