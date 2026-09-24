import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../add_thing/domain/thing_recognition.dart';
import '../domain/thing.dart';

class ThingRepository {
  ThingRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Stream<List<Thing>> watchMyThings() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('things')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final things = snapshot.docs
          .map((doc) => Thing.fromMap(doc.id, doc.data()))
          .toList();

      things.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return things;
    });
  }

  Future<String> createThing({
    required Uint8List imageBytes,
    required String mimeType,
    required ThingRecognition recognition,
    required String name,
    required String categoryId,
    required String subcategory,
    required String brand,
    required String model,
    required String condition,
    required String description,
    required int estimatedNewPriceIls,
    required int estimatedCurrentValueIls,
    required Set<ThingAction> enabledActions,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to save a Thing.');
    }

    final document = _firestore.collection('things').doc();
    final extension = _extensionForMimeType(mimeType);
    final storageRef = _storage.ref().child(
          'users/${user.uid}/things/${document.id}/original.$extension',
        );

    await storageRef
        .putData(
          imageBytes,
          SettableMetadata(contentType: mimeType),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException(
              'Photo upload timed out. Check Firebase Storage setup and rules.',
            );
          },
        );

    final downloadUrl = await storageRef.getDownloadURL().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException(
          'Could not get the uploaded photo URL from Firebase Storage.',
        );
      },
    );
    final now = FieldValue.serverTimestamp();

    await document.set({
      'id': document.id,
      'ownerId': user.uid,
      'name': name.trim(),
      'categoryId': categoryId.trim().isEmpty ? 'other' : categoryId.trim(),
      'subcategoryId': subcategory.trim().isEmpty ? null : subcategory.trim(),
      'description': description.trim(),
      'photoUrls': [downloadUrl],
      'photoStoragePaths': [storageRef.fullPath],
      'attributes': {
        'brand': brand.trim(),
        'model': model.trim(),
        'aiConfidence': recognition.confidence,
        'recognizedBy': 'gemini-3.8-flash',
      },
      'searchKeywords': {
        ...recognition.searchKeywords.map((value) => value.toLowerCase()),
        name.trim().toLowerCase(),
        if (brand.trim().isNotEmpty) brand.trim().toLowerCase(),
        if (model.trim().isNotEmpty) model.trim().toLowerCase(),
      }.toList(),
      'quantity': 1,
      'condition': _normalizeCondition(condition),
      'visibility': enabledActions.any(
        (action) => action != ThingAction.personalUse,
      )
          ? 'public'
          : 'private',
      'enabledActions': enabledActions.map((action) => action.name).toList(),
      'estimatedNewPrice': estimatedNewPriceIls > 0
          ? estimatedNewPriceIls.toDouble()
          : null,
      'estimatedCurrentValue': estimatedCurrentValueIls > 0
          ? estimatedCurrentValueIls.toDouble()
          : null,
      'createdAt': now,
      'updatedAt': now,
      'ai': {
        'confidence': recognition.confidence,
        'model': 'gemini-3.8-flash',
      },
    }).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw TimeoutException(
          'Firestore save timed out. Check Firestore setup and rules.',
        );
      },
    );

    return document.id;
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

  String _normalizeCondition(String value) {
    switch (value) {
      case 'new':
        return 'newItem';
      case 'like_new':
        return 'likeNew';
      case 'good':
      case 'fair':
      case 'poor':
        return value;
      default:
        return 'unknown';
    }
  }
}
