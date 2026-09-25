import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/background_scan_item.dart';

class BackgroundScanStartResult {
  const BackgroundScanStartResult({
    required this.jobId,
    required this.sourceUrl,
  });

  final String jobId;
  final String sourceUrl;
}

class BackgroundScanRepository {
  BackgroundScanRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }
    return user;
  }

  Future<BackgroundScanStartResult> startScan({
    required Uint8List imageBytes,
    required String mimeType,
    required String fileName,
    void Function(double progress)? onUploadProgress,
  }) async {
    final user = _user;
    final jobRef = _firestore.collection('scanJobs').doc();
    final extension = _extensionForMimeType(mimeType);
    final sourceRef = _storage.ref().child(
          'users/${user.uid}/scanJobs/${jobRef.id}/source.$extension',
        );

    Object? lastError;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final task = sourceRef.putData(
          imageBytes,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {
              'keepiScanJobId': jobRef.id,
              'originalFileName': fileName,
            },
          ),
        );

        final subscription = task.snapshotEvents.listen((snapshot) {
          final total = snapshot.totalBytes;
          if (total <= 0) return;
          onUploadProgress?.call(snapshot.bytesTransferred / total);
        });

        try {
          await task.timeout(const Duration(seconds: 120));
        } finally {
          await subscription.cancel();
        }

        lastError = null;
        break;
      } catch (error) {
        lastError = error;

        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    if (lastError != null) {
      throw StateError(
        'Could not upload the scan photo after 3 attempts: $lastError',
      );
    }

    final sourceUrl = await sourceRef
        .getDownloadURL()
        .timeout(const Duration(seconds: 30));

    await jobRef.set({
      'ownerId': user.uid,
      'ownerDisplayName': _displayNameFor(user),
      'status': 'queued',
      'stage': 'queued',
      'progress': 0.01,
      'message': 'Scan queued on Keepi servers...',
      'sourceStoragePath': sourceRef.fullPath,
      'sourceUrl': sourceUrl,
      'originalFileName': fileName,
      'sourceMimeType': mimeType,
      'totalDetected': 0,
      'processedCount': 0,
      'identifiedCount': 0,
      'failedItems': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return BackgroundScanStartResult(
      jobId: jobRef.id,
      sourceUrl: sourceUrl,
    );
  }

  Stream<Map<String, dynamic>?> watchJob(String jobId) {
    return _firestore.collection('scanJobs').doc(jobId).snapshots().map(
          (snapshot) => snapshot.exists
              ? {
                  'id': snapshot.id,
                  ...?snapshot.data(),
                }
              : null,
        );
  }

  Future<List<BackgroundScanItem>> loadItems(String jobId) async {
    final snapshot = await _firestore
        .collection('scanJobs')
        .doc(jobId)
        .collection('items')
        .get();

    final items = snapshot.docs
        .where((doc) => doc.data()['status'] == 'identified')
        .map((doc) => BackgroundScanItem.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return items;
  }

  Future<Map<String, dynamic>?> findLatestUnreviewedJob() async {
    final user = _user;

    final snapshot = await _firestore
        .collection('scanJobs')
        .where('ownerId', isEqualTo: user.uid)
        .get();

    final jobs = snapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            ...doc.data(),
          },
        )
        .where((job) => job['reviewedAt'] == null)
        .toList();

    if (jobs.isEmpty) {
      return null;
    }

    DateTime dateFor(Map<String, dynamic> job) {
      final value = job['createdAt'];
      if (value is Timestamp) return value.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    jobs.sort((a, b) => dateFor(b).compareTo(dateFor(a)));

    final latest = jobs.first;
    final created = dateFor(latest);

    if (DateTime.now().difference(created).inDays > 7) {
      return null;
    }

    return latest;
  }

  Future<void> markReviewed(String jobId) async {
    await _firestore.collection('scanJobs').doc(jobId).set({
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _displayNameFor(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Keepi user';
  }

  String _extensionForMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }
}
