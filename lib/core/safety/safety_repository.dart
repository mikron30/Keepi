import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyRepository {
  SafetyRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _blockedRef =>
      _firestore.collection('users').doc(_uid).collection('blockedUsers');

  Stream<Set<String>> watchBlockedUserIds() {
    return _blockedRef.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
        );
  }

  Future<void> blockUser(String blockedUserId) async {
    if (blockedUserId.isEmpty || blockedUserId == _uid) return;
    await _blockedRef.doc(blockedUserId).set({
      'blockedUserId': blockedUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String blockedUserId) async {
    await _blockedRef.doc(blockedUserId).delete();
  }

  Future<void> reportUser({
    required String reportedUserId,
    String? conversationId,
    String reason = 'objectionable_content_or_behavior',
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': _uid,
      'reportedUserId': reportedUserId,
      'conversationId': conversationId,
      'reason': reason,
      'type': 'user',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportThing({
    required String thingId,
    required String ownerId,
    String reason = 'objectionable_content_or_listing',
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': _uid,
      'reportedUserId': ownerId,
      'thingId': thingId,
      'reason': reason,
      'type': 'thing',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
