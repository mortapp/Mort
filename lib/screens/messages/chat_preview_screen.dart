import 'package:flutter/material.dart';
import '../../models/mock_message.dart';
import '../../services/messages_backend_service.dart';
import '../../theme/mort_theme.dart';
import '../../widgets/mort_button.dart';

class ChatPreviewScreen extends StatefulWidget {
  final MockMessagePreview preview;

  const ChatPreviewScreen({super.key, required this.preview});

  @override
  State<ChatPreviewScreen> createState() => _ChatPreviewScreenState();
}

class _ChatPreviewScreenState extends State<ChatPreviewScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  String? _error;
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // For demo: just show preview
    // In real app: load from backend
    if (!mounted) return;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _error = 'Message cannot be empty.';
      });
      return;
    }

    // Check for unsafe content
    final unsafeError = SafeMessage.getUnsafeContentError(content);
    if (unsafeError != null) {
      setState(() {
        _error = unsafeError;
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    // Try to send via backend - for now just show demo
    final success =
        true; // In real app: await MessagesBackendService.instance.sendMessage(recipientId, content);

    if (!mounted) return;
    setState(() {
      _sending = false;
    });

    if (success) {
      _messageController.clear();
      setState(() {
        _error = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent (demo mode)')));
    } else {
      setState(() {
        _error = 'Failed to send message. Try again.';
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MortTheme.background,
      appBar: AppBar(
        title: Text('@${widget.preview.username}'),
        backgroundColor: MortTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Card(
                color: MortTheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'This is a demo preview. Messaging backend is being implemented. Never move job communication off MORT.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _messageBubble(
                      'Hi, I can help with this job safely.',
                      false,
                    ),
                    _messageBubble(widget.preview.preview, true),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _messageController,
                enabled: !_sending,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: MortTheme.elevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  helperText:
                      'Keep phone numbers, emails, and payment info off MORT',
                  helperStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: null,
              ),
              const SizedBox(height: 8),
              MortButton(
                onPressed: _sending ? null : _sendMessage,
                child: Text(_sending ? 'Sending…' : 'Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(String text, bool incoming) {
    return Align(
      alignment: incoming ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: incoming ? MortTheme.primaryPurple : MortTheme.elevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}
