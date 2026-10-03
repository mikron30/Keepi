import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/safety/safety_repository.dart';
import '../data/chat_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.conversationId,
    super.key,
  });

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  late final ChatRepository _repository;
  final _safetyRepository = SafetyRepository();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) {
      return;
    }

    final message = _controller.text;
    _controller.clear();
    setState(() => _sending = true);

    try {
      await _repository.sendMessage(
        conversationId: widget.conversationId,
        text: message,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String? _otherUserId(Map<String, dynamic>? conversation) {
    if (conversation == null) return null;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final ids = (conversation['participantIds'] as List<dynamic>? ?? const [])
        .map((value) => value.toString());
    for (final id in ids) {
      if (id.isNotEmpty && id != currentUid) return id;
    }
    return null;
  }

  Future<void> _reportUser(Map<String, dynamic>? conversation) async {
    final otherUserId = _otherUserId(conversation);
    if (otherUserId == null) return;

    await _safetyRepository.reportUser(
      reportedUserId: otherUserId,
      conversationId: widget.conversationId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to Keepi.')),
      );
    }
  }

  Future<void> _blockUser(Map<String, dynamic>? conversation) async {
    final otherUserId = _otherUserId(conversation);
    if (otherUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'Their items will be hidden from your Explore results. '
          'You can contact Keepi support if you also need help with a report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _safetyRepository.blockUser(otherUserId);
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _repository.watchConversation(widget.conversationId),
      builder: (context, conversationSnapshot) {
        final conversation = conversationSnapshot.data;
        final title = conversation == null
            ? 'Chat'
            : _repository.otherParticipantName(conversation);
        final thingName =
            (conversation?['thingName'] ?? '').toString().trim();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (thingName.isNotEmpty)
                  Text(
                    thingName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Safety',
                onSelected: (value) {
                  if (value == 'report') {
                    _reportUser(conversation);
                  } else if (value == 'block') {
                    _blockUser(conversation);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: ListTile(
                      leading: Icon(Icons.flag_outlined),
                      title: Text('Report user'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: ListTile(
                      leading: Icon(Icons.block),
                      title: Text('Block user'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _repository.watchMessages(widget.conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Could not load chat: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('Start the conversation.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _MessageBubble(message: messages[index]);
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final mine = message['senderId'] == currentUid;
    final text = (message['text'] ?? '').toString();
    final createdAt = message['createdAt'];

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(text),
            ),
            const SizedBox(height: 4),
            Text(
              _time(createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _time(dynamic value) {
    if (value is! Timestamp) {
      return '';
    }

    final date = value.toDate().toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
