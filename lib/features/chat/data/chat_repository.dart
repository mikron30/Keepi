import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRepository {
  ChatRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }
    return user;
  }

  Stream<List<Map<String, dynamic>>> watchConversations() {
    final uid = _user.uid;

    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      items.sort((a, b) {
        DateTime dateFor(Map<String, dynamic> item) {
          final value = item['lastMessageAt'] ?? item['createdAt'];
          if (value is Timestamp) return value.toDate();
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        return dateFor(b).compareTo(dateFor(a));
      });

      return items;
    });
  }

  Stream<Map<String, dynamic>?> watchConversation(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? {
                  'id': snapshot.id,
                  ...?snapshot.data(),
                }
              : null,
        );
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ...doc.data(),
                },
              )
              .toList(),
        );
  }

  Future<String> ensureConversation({
    required String otherUserId,
    required String otherDisplayName,
    String? thingId,
    String? thingName,
  }) async {
    final user = _user;

    if (otherUserId == user.uid) {
      throw StateError('You cannot start a chat with yourself.');
    }

    final ids = [user.uid, otherUserId]..sort();
    final contextId =
        (thingId == null || thingId.isEmpty) ? 'general' : thingId;
    final conversationId = '${ids[0]}_${ids[1]}_$contextId';
    final reference =
        _firestore.collection('conversations').doc(conversationId);
    final existing = await reference.get();

    if (!existing.exists) {
      await reference.set({
        'participantIds': ids,
        'participantNames': {
          user.uid: user.displayName?.trim().isNotEmpty == true
              ? user.displayName
              : user.email ?? 'Keepi user',
          otherUserId: otherDisplayName.trim().isEmpty
              ? 'Keepi user'
              : otherDisplayName.trim(),
        },
        'thingId': thingId,
        'thingName': thingName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }

    return conversationId;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final user = _user;
    final conversation =
        _firestore.collection('conversations').doc(conversationId);
    final message = conversation.collection('messages').doc();

    final batch = _firestore.batch();

    batch.set(message, {
      'senderId': user.uid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [user.uid],
    });

    batch.update(conversation, {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  String otherParticipantName(Map<String, dynamic> conversation) {
    final uid = _user.uid;
    final ids = (conversation['participantIds'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList();

    final otherId = ids.firstWhere(
      (id) => id != uid,
      orElse: () => '',
    );

    final names = conversation['participantNames'];
    if (names is Map && names[otherId] != null) {
      return names[otherId].toString();
    }

    return 'Keepi user';
  }
}
