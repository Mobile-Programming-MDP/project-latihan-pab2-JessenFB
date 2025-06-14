import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/chat_history_service.dart';
import 'navigation_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ChatMessage> _messages = [];
  late ChatHistoryService _chatService;
  bool _isTyping = false;
  bool _stopTyping = false;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    final userId = _auth.currentUser?.uid ?? 'guest_user';
    _chatService = ChatHistoryService(userId);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _chatService.getMessages();
    if (!_isMounted) return;
    setState(() {
      _messages = history;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    final typoWarning = AIService.detectPossibleTypos(text);
    if (typoWarning != null && _isMounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(typoWarning)),
      );
    }

    final userMsg = ChatMessage(
      sender: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    if (!_isMounted) return;
    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
      _stopTyping = false;
      _controller.clear();
    });

    await _chatService.saveMessage(userMsg);
    await Future.delayed(const Duration(milliseconds: 100));

    if (!_isMounted) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    final fullResponse = await AIService.ask(text);
    String displayedText = '';

    for (int i = 0; i < fullResponse.length; i++) {
      if (_stopTyping || !_isMounted) break;

      displayedText += fullResponse[i];

      final aiMsg = ChatMessage(
        sender: 'ai',
        content: displayedText,
        timestamp: DateTime.now(),
      );

      if (!_isMounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.last.sender == 'ai') {
          _messages[_messages.length - 1] = aiMsg;
        } else {
          _messages.add(aiMsg);
        }
      });

      await Future.delayed(const Duration(milliseconds: 30));

      if (!_isMounted) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 50,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    if (!_stopTyping && _isMounted) {
      await _chatService.saveMessage(_messages.last);
    }

    if (!_isMounted) return;
    setState(() {
      _isTyping = false;
    });
  }

  void _stopMessage() {
    if (!_isMounted) return;
    setState(() {
      _stopTyping = true;
      _isTyping = false;
    });
  }

  Widget _buildMessage(ChatMessage msg) {
    final isUser = msg.sender == 'user';
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final maxWidth = isUser ? 300.0 : MediaQuery.of(context).size.width * 0.85;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isUser
        ? const Color(0xFF38BDF8)
        : isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFDDE3EA);

    final textColor = isUser
        ? Colors.white
        : isDark
            ? Colors.white70
            : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: MarkdownBody(
          data: msg.content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 15),
            strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
            code: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.amberAccent,
              backgroundColor: Colors.black54,
            ),
            blockquote: TextStyle(color: textColor.withOpacity(0.8)),
          ),
        ),
      ),
    );
  }

  Future<void> _clearHistory() async {
    await _chatService.clearHistory();
    if (!_isMounted) return;
    setState(() => _messages.clear());
  }

  @override
  void dispose() {
    _isMounted = false;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Gym AI Chat',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note, color: isDark ? Colors.white : Colors.black),
            tooltip: 'New chat',
            onPressed: () async {
              await _clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New chat started')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: "Input text here...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.grey.withOpacity(0.75),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isTyping ? Icons.stop : Icons.send,
                    color: const Color(0xFF38BDF8),
                  ),
                  onPressed: _isTyping ? _stopMessage : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(
        currentIndex: 2,
      ),
    );
  }
}
