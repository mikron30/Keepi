import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/chat_repository.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final ChatRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repository.watchConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load messages: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data!;
          if (conversations.isEmpty) {
            return const _EmptyMessages();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final id = conversation['id'].toString();
              final otherName =
                  _repository.otherParticipantName(conversation);
              final thingName =
                  (conversation['thingName'] ?? '').toString().trim();
              final lastMessage =
                  (conversation['lastMessage'] ?? '').toString().trim();
              final lastMessageAt = conversation['lastMessageAt'];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      otherName.isEmpty ? 'K' : otherName[0].toUpperCase(),
                    ),
                  ),
                  title: Text(
                    otherName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      if (thingName.isNotEmpty) thingName,
                      if (lastMessage.isNotEmpty) lastMessage,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _formatTime(lastMessageAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => context.push('/messages/$id'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) {
      return '';
    }

    final date = value.toDate().toLocal();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '${date.day}/${date.month}';
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 68),
            SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Open a nearby Thing and message its owner. '
              'Your phone number stays private.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
