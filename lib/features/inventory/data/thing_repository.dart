import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../add_thing/domain/scanned_thing_candidate.dart';
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

  Stream<List<Thing>> watchPublicThings() {
    return _firestore
        .collection('things')
        .where('visibility', isEqualTo: 'public')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Thing.fromMap(doc.id, doc.data()))
              .toList(),
        );
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
    final user = _requireUser();

    final document = _firestore.collection('things').doc();
    final extension = _extensionForMimeType(mimeType);
    final storageRef = _storage.ref().child(
          'users/${user.uid}/things/${document.id}/original.$extension',
        );

    await _uploadBytes(
      storageRef: storageRef,
      imageBytes: imageBytes,
      mimeType: mimeType,
    );

    final downloadUrl = await _downloadUrl(storageRef);
    final location = await _defaultThingLocation(user.uid);

    await document
        .set(
          _thingMap(
            id: document.id,
            ownerId: user.uid,
            ownerDisplayName: _displayNameFor(user),
            recognition: recognition,
            name: name,
            categoryId: categoryId,
            subcategory: subcategory,
            brand: brand,
            model: model,
            condition: condition,
            description: description,
            estimatedNewPriceIls: estimatedNewPriceIls,
            estimatedCurrentValueIls: estimatedCurrentValueIls,
            enabledActions: enabledActions,
            photoUrls: [downloadUrl],
            photoStoragePaths: [storageRef.fullPath],
            location: location,
          ),
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw TimeoutException(
              'Firestore save timed out. Check Firestore setup and rules.',
            );
          },
        );

    if (location != null) {
      await _savePrivateThingLocation(
        ownerId: user.uid,
        thingId: document.id,
        latitude: location['latitude']!,
        longitude: location['longitude']!,
        label: 'Home',
      );
    }

    return document.id;
  }

  Future<int> createThingsFromScan({
    required Uint8List imageBytes,
    required String mimeType,
    required List<ThingRecognition> recognitions,
  }) async {
    if (recognitions.isEmpty) {
      return 0;
    }

    final user = _requireUser();
    final scanId = _firestore.collection('scan_ids').doc().id;
    final extension = _extensionForMimeType(mimeType);
    final storageRef = _storage.ref().child(
          'users/${user.uid}/scans/$scanId/source.$extension',
        );

    await _uploadBytes(
      storageRef: storageRef,
      imageBytes: imageBytes,
      mimeType: mimeType,
    );

    final downloadUrl = await _downloadUrl(storageRef);
    final location = await _defaultThingLocation(user.uid);
    final batch = _firestore.batch();

    for (final recognition in recognitions.take(50)) {
      final document = _firestore.collection('things').doc();

      batch.set(
        document,
        _thingMap(
          id: document.id,
          ownerId: user.uid,
          ownerDisplayName: _displayNameFor(user),
          recognition: recognition,
          name: recognition.name,
          categoryId: recognition.categoryId,
          subcategory: recognition.subcategory,
          brand: recognition.brand,
          model: recognition.model,
          condition: recognition.condition,
          description: recognition.description,
          estimatedNewPriceIls: recognition.estimatedNewPriceIls,
          estimatedCurrentValueIls: recognition.estimatedCurrentValueIls,
          enabledActions: const {ThingAction.personalUse},
          photoUrls: [downloadUrl],
          photoStoragePaths: [storageRef.fullPath],
          location: location,
          scanId: scanId,
        ),
      );

      if (location != null) {
        batch.set(
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('thingLocations')
              .doc(document.id),
          {
            'thingId': document.id,
            'latitude': location['latitude'],
            'longitude': location['longitude'],
            'label': 'Home',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException(
          'Batch save timed out. Check Firestore setup and rules.',
        );
      },
    );

    return recognitions.take(50).length;
  }

  Future<int> createThingsFromMultiScan({
    required Uint8List sourceImageBytes,
    required String sourceMimeType,
    required List<ScannedThingCandidate> candidates,
  }) async {
    if (candidates.isEmpty) {
      return 0;
    }

    final user = _requireUser();
    final selected = candidates.take(50).toList();
    final scanId = _firestore.collection('scan_ids').doc().id;
    final sourceExtension = _extensionForMimeType(sourceMimeType);
    final sourceRef = _storage.ref().child(
          'users/${user.uid}/scans/$scanId/source.$sourceExtension',
        );

    await _uploadBytes(
      storageRef: sourceRef,
      imageBytes: sourceImageBytes,
      mimeType: sourceMimeType,
    );

    final sourceUrl = await _downloadUrl(sourceRef);

    final tileCandidates = <int, ScannedThingCandidate>{};
    for (final candidate in selected) {
      tileCandidates.putIfAbsent(candidate.tileIndex, () => candidate);
    }

    final tileUrls = <int, String>{};
    final tilePaths = <int, String>{};

    for (final entry in tileCandidates.entries) {
      final tileRef = _storage.ref().child(
            'users/${user.uid}/scans/$scanId/tile_${entry.key}.jpg',
          );

      await _uploadBytes(
        storageRef: tileRef,
        imageBytes: entry.value.tileBytes,
        mimeType: 'image/jpeg',
      );

      tileUrls[entry.key] = await _downloadUrl(tileRef);
      tilePaths[entry.key] = tileRef.fullPath;
    }

    final location = await _defaultThingLocation(user.uid);
    final batch = _firestore.batch();

    for (final candidate in selected) {
      final recognition = candidate.recognition;
      final document = _firestore.collection('things').doc();
      final tileUrl = tileUrls[candidate.tileIndex];
      final tilePath = tilePaths[candidate.tileIndex];

      batch.set(
        document,
        _thingMap(
          id: document.id,
          ownerId: user.uid,
          ownerDisplayName: _displayNameFor(user),
          recognition: recognition,
          name: recognition.name,
          categoryId: recognition.categoryId,
          subcategory: recognition.subcategory,
          brand: recognition.brand,
          model: recognition.model,
          condition: recognition.condition,
          description: recognition.description,
          estimatedNewPriceIls: recognition.estimatedNewPriceIls,
          estimatedCurrentValueIls: recognition.estimatedCurrentValueIls,
          enabledActions: const {ThingAction.personalUse},
          photoUrls: [
            ?tileUrl,
            sourceUrl,
          ],
          photoStoragePaths: [
            ?tilePath,
            sourceRef.fullPath,
          ],
          location: location,
          scanId: scanId,
        ),
      );

      if (location != null) {
        batch.set(
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('thingLocations')
              .doc(document.id),
          {
            'thingId': document.id,
            'latitude': location['latitude'],
            'longitude': location['longitude'],
            'label': 'Home',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException(
          'Batch save timed out. Check Firestore setup and rules.',
        );
      },
    );

    return selected.length;
  }

  Future<void> markThingLent({
    required String thingId,
    required String borrowerName,
    String? borrowerUserId,
    DateTime? dueAt,
    double? latitude,
    double? longitude,
  }) async {
    final user = _requireUser();
    final reference = _firestore.collection('things').doc(thingId);
    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data?['ownerId'] != user.uid) {
      throw StateError('Only the owner can mark this Thing as lent.');
    }

    final updates = <String, dynamic>{
      'currentHolderUserId': borrowerUserId,
      'currentHolderName': borrowerName.trim(),
      'loanedAt': FieldValue.serverTimestamp(),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'locationLabel': 'With ${borrowerName.trim()}',
      'visibilityBeforeLoan': data?['visibility'] ?? 'private',
      'visibility': 'private',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (latitude != null) {
      updates['latitude'] = _coarseCoordinate(latitude);
    }
    if (longitude != null) {
      updates['longitude'] = _coarseCoordinate(longitude);
    }

    await reference.update(updates);

    if (latitude != null && longitude != null) {
      await _savePrivateThingLocation(
        ownerId: user.uid,
        thingId: thingId,
        latitude: latitude,
        longitude: longitude,
        label: 'With ${borrowerName.trim()}',
      );
    }
  }

  Future<void> markThingReturned(String thingId) async {
    final user = _requireUser();
    final location = await _defaultThingLocation(user.uid);
    final reference = _firestore.collection('things').doc(thingId);
    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data?['ownerId'] != user.uid) {
      throw StateError('Only the owner can mark this Thing as returned.');
    }

    final updates = <String, dynamic>{
      'currentHolderUserId': null,
      'currentHolderName': null,
      'loanedAt': null,
      'dueAt': null,
      'locationLabel': location == null ? 'With me' : 'Home',
      'visibility': data?['visibilityBeforeLoan'] ?? 'private',
      'visibilityBeforeLoan': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (location != null) {
      updates['latitude'] = _coarseCoordinate(location['latitude']!);
      updates['longitude'] = _coarseCoordinate(location['longitude']!);
    }

    await reference.update(updates);

    if (location != null) {
      await _savePrivateThingLocation(
        ownerId: user.uid,
        thingId: thingId,
        latitude: location['latitude']!,
        longitude: location['longitude']!,
        label: 'Home',
      );
    }
  }

  Future<Map<String, double>?> _defaultThingLocation(String uid) async {
    final profile = (await _firestore.collection('users').doc(uid).get()).data();
    if (profile == null) {
      return null;
    }

    Map<String, double>? read(dynamic raw) {
      if (raw is! Map) {
        return null;
      }

      final latitude = raw['latitude'];
      final longitude = raw['longitude'];

      if (latitude is! num || longitude is! num) {
        return null;
      }

      return {
        'latitude': latitude.toDouble(),
        'longitude': longitude.toDouble(),
      };
    }

    return read(profile['homeLocation']) ?? read(profile['currentLocation']);
  }

  Map<String, dynamic> _thingMap({
    required String id,
    required String ownerId,
    required String ownerDisplayName,
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
    required List<String> photoUrls,
    required List<String> photoStoragePaths,
    required Map<String, double>? location,
    String? scanId,
  }) {
    final now = FieldValue.serverTimestamp();
    final attributes = <String, dynamic>{
      'brand': brand.trim(),
      'model': model.trim(),
      'aiConfidence': recognition.confidence,
      'recognizedBy': 'agent-platform-gemini',
    };

    if (scanId != null) {
      attributes['scanId'] = scanId;
    }

    return {
      'id': id,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'name': name.trim(),
      'categoryId': categoryId.trim().isEmpty ? 'other' : categoryId.trim(),
      'subcategoryId': subcategory.trim().isEmpty ? null : subcategory.trim(),
      'description': description.trim(),
      'photoUrls': photoUrls,
      'photoStoragePaths': photoStoragePaths,
      'attributes': attributes,
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
      'latitude': location == null
          ? null
          : _coarseCoordinate(location['latitude']!),
      'longitude': location == null
          ? null
          : _coarseCoordinate(location['longitude']!),
      'locationLabel': location == null ? null : 'Home',
      'currentHolderUserId': null,
      'currentHolderName': null,
      'loanedAt': null,
      'dueAt': null,
      'createdAt': now,
      'updatedAt': now,
      'ai': {
        'confidence': recognition.confidence,
        'model': 'agent-platform-gemini',
      },
    };
  }

  Future<void> _savePrivateThingLocation({
    required String ownerId,
    required String thingId,
    required double latitude,
    required double longitude,
    required String label,
  }) {
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('thingLocations')
        .doc(thingId)
        .set({
      'thingId': thingId,
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  double _coarseCoordinate(double value) {
    return (value * 100).round() / 100;
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

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }
    return user;
  }

  Future<void> _uploadBytes({
    required Reference storageRef,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
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
  }

  Future<String> _downloadUrl(Reference storageRef) {
    return storageRef.getDownloadURL().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException(
          'Could not get the uploaded photo URL from Firebase Storage.',
        );
      },
    );
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
