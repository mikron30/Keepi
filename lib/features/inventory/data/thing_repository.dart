import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

import '../../add_thing/domain/background_scan_item.dart';
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

  Stream<Thing?> watchThing(String thingId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore.collection('things').doc(thingId).snapshots().map(
          (snapshot) {
            final data = snapshot.data();
            if (!snapshot.exists || data == null) {
              return null;
            }

            if (data['ownerId'] != user.uid) {
              return null;
            }

            return Thing.fromMap(snapshot.id, data);
          },
        );
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
    String? expiryDateIso,
    String? expiryDateSource,
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
            thumbnailUrl: downloadUrl,
            location: location,
            expiryDateIsoOverride: expiryDateIso,
            expiryDateSourceOverride: expiryDateSource,
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
          thumbnailUrl: downloadUrl,
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
    void Function(int completed, int total, String stage)? onProgress,
  }) async {
    if (candidates.isEmpty) {
      return 0;
    }

    final user = _requireUser();
    final selected = candidates.take(60).toList();
    final scanId = _firestore.collection('scan_ids').doc().id;
    final preparedSource = _prepareSourceForStorage(sourceImageBytes);
    final sourceRef = _storage.ref().child(
          'users/${user.uid}/scans/$scanId/source.jpg',
        );

    final totalUploads = selected.length + 1;
    var completedUploads = 0;
    onProgress?.call(
      completedUploads,
      totalUploads,
      'Uploading source image...',
    );

    await _uploadBytesWithRetry(
      storageRef: sourceRef,
      imageBytes: preparedSource,
      mimeType: 'image/jpeg',
    );

    final sourceUrl = await _downloadUrlWithRetry(sourceRef);
    completedUploads++;
    onProgress?.call(
      completedUploads,
      totalUploads,
      'Source uploaded',
    );

    final cropUrls = <int, String>{};
    final cropPaths = <int, String>{};

    const parallelUploads = 4;
    for (var start = 0; start < selected.length; start += parallelUploads) {
      final end = math.min(start + parallelUploads, selected.length);
      final group = selected.sublist(start, end);

      final results = await Future.wait(
        group.map((candidate) async {
          final cropRef = _storage.ref().child(
                'users/${user.uid}/scans/$scanId/crop_${candidate.itemIndex}.jpg',
              );

          await _uploadBytesWithRetry(
            storageRef: cropRef,
            imageBytes: candidate.cropBytes,
            mimeType: 'image/jpeg',
          );

          final url = await _downloadUrlWithRetry(cropRef);
          return (
            itemIndex: candidate.itemIndex,
            url: url,
            path: cropRef.fullPath,
          );
        }),
      );

      for (final result in results) {
        cropUrls[result.itemIndex] = result.url;
        cropPaths[result.itemIndex] = result.path;
        completedUploads++;
      }

      onProgress?.call(
        completedUploads,
        totalUploads,
        'Uploaded ${completedUploads - 1}/${selected.length} product images',
      );
    }

    final location = await _defaultThingLocation(user.uid);
    final batch = _firestore.batch();

    for (final candidate in selected) {
      final recognition = candidate.recognition;
      final document = _firestore.collection('things').doc();
      final cropUrl = cropUrls[candidate.itemIndex];
      final cropPath = cropPaths[candidate.itemIndex];

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
            ?cropUrl,
            sourceUrl,
          ],
          photoStoragePaths: [
            ?cropPath,
            sourceRef.fullPath,
          ],
          thumbnailUrl: cropUrl ?? sourceUrl,
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

    onProgress?.call(
      totalUploads,
      totalUploads,
      'Saving inventory records...',
    );

    await batch.commit().timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw TimeoutException(
          'Batch save timed out. Check Firestore setup and rules.',
        );
      },
    );

    onProgress?.call(
      totalUploads,
      totalUploads,
      'Saved ${selected.length} Things',
    );

    return selected.length;
  }

  Future<int> createThingsFromBackgroundScan({
    required String scanJobId,
    required List<BackgroundScanItem> items,
    Map<String, String> editedNames = const {},
    Map<String, String> editedExpiryDates = const {},
  }) async {
    if (items.isEmpty) {
      return 0;
    }

    final user = _requireUser();
    final selected = items.take(100).toList();
    final location = await _defaultThingLocation(user.uid);
    final batch = _firestore.batch();

    for (final item in selected) {
      final document = _firestore.collection('things').doc();
      final recognition = ThingRecognition(
        name: editedNames[item.id]?.trim().isNotEmpty == true
            ? editedNames[item.id]!.trim()
            : item.name,
        categoryId: item.categoryId,
        subcategory: item.subcategory,
        brand: item.brand,
        model: item.model,
        condition: item.condition,
        description: item.description,
        estimatedNewPriceIls: item.estimatedNewPriceIls,
        estimatedCurrentValueIls: item.estimatedCurrentValueIls,
        confidence: item.confidence,
        searchKeywords: item.searchKeywords,
        expiryDateIso: editedExpiryDates.containsKey(item.id)
            ? _normalizeExpiryDateText(editedExpiryDates[item.id])
            : item.expiryDateIso,
        expiryDateSource: editedExpiryDates.containsKey(item.id)
            ? (editedExpiryDates[item.id]?.trim().isEmpty == true
                ? 'unknown'
                : 'manual')
            : item.expiryDateSource,
      );

      final photoUrls = <String>[
        if (item.cropUrl.isNotEmpty) item.cropUrl,
        if (item.sourceUrl.isNotEmpty) item.sourceUrl,
      ];
      final storagePaths = <String>[
        if (item.cropStoragePath.isNotEmpty) item.cropStoragePath,
        if (item.sourceStoragePath.isNotEmpty) item.sourceStoragePath,
      ];

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
          photoUrls: photoUrls,
          photoStoragePaths: storagePaths,
          thumbnailUrl:
              item.cropUrl.isNotEmpty ? item.cropUrl : item.sourceUrl,
          location: location,
          scanId: scanJobId,
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
      const Duration(seconds: 60),
      onTimeout: () {
        throw TimeoutException(
          'Saving inventory records timed out. Please try again.',
        );
      },
    );

    return selected.length;
  }

  Future<void> updateThingDetails({
    required String thingId,
    required String name,
    required String categoryId,
    required String subcategory,
    required String brand,
    required String model,
    required ThingCondition condition,
    required String description,
    required int quantity,
    required double? estimatedNewPrice,
    required double? estimatedCurrentValue,
    required DateTime? expiryDate,
    required String locationLabel,
    required Set<ThingAction> enabledActions,
  }) async {
    final user = _requireUser();
    final reference = _firestore.collection('things').doc(thingId);
    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data?['ownerId'] != user.uid) {
      throw StateError('Only the owner can edit this Thing.');
    }

    final normalizedName = name.trim().isEmpty ? 'Unnamed Thing' : name.trim();
    final normalizedCategory =
        categoryId.trim().isEmpty ? 'other' : categoryId.trim();

    final existingKeywords =
        (data?['searchKeywords'] as List<dynamic>? ?? const [])
            .map((value) => value.toString().toLowerCase())
            .where((value) => value.trim().isNotEmpty)
            .toSet();

    final keywords = <String>{
      ...existingKeywords,
      normalizedName.toLowerCase(),
      if (brand.trim().isNotEmpty) brand.trim().toLowerCase(),
      if (model.trim().isNotEmpty) model.trim().toLowerCase(),
      if (subcategory.trim().isNotEmpty) subcategory.trim().toLowerCase(),
    }.toList();

    final isPublic = enabledActions.any(
      (action) => action != ThingAction.personalUse,
    );

    await reference.update({
      'name': normalizedName,
      'categoryId': normalizedCategory,
      'subcategoryId':
          subcategory.trim().isEmpty ? null : subcategory.trim(),
      'description': description.trim(),
      'quantity': quantity < 1 ? 1 : quantity,
      'condition': condition.name,
      'estimatedNewPrice': estimatedNewPrice,
      'estimatedCurrentValue': estimatedCurrentValue,
      'expiryDate':
          expiryDate == null ? null : Timestamp.fromDate(expiryDate),
      'locationLabel':
          locationLabel.trim().isEmpty ? null : locationLabel.trim(),
      'enabledActions':
          enabledActions.map((action) => action.name).toList(),
      'visibility': isPublic ? 'public' : 'private',
      'searchKeywords': keywords,
      'attributes.brand': brand.trim(),
      'attributes.model': model.trim(),
      'attributes.expiryDateSource':
          expiryDate == null ? 'unknown' : 'manual',
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    String? thumbnailUrl,
    required Map<String, double>? location,
    String? scanId,
    String? expiryDateIsoOverride,
    String? expiryDateSourceOverride,
  }) {
    final now = FieldValue.serverTimestamp();
    final expiryDateIso =
        expiryDateIsoOverride ?? recognition.expiryDateIso;
    final expiryDateSource =
        expiryDateSourceOverride ?? recognition.expiryDateSource;
    final expiryDate = _parseExpiryDate(expiryDateIso);

    final attributes = <String, dynamic>{
      'brand': brand.trim(),
      'model': model.trim(),
      'aiConfidence': recognition.confidence,
      'recognizedBy': 'agent-platform-gemini',
      'expiryDateSource': expiryDateSource,
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
      'thumbnailUrl': thumbnailUrl ?? (photoUrls.isEmpty ? null : photoUrls.first),
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
      'expiryDate':
          expiryDate == null ? null : Timestamp.fromDate(expiryDate),
      'openedAt': null,
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

  Uint8List _prepareSourceForStorage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return bytes;
      }

      var image = img.bakeOrientation(decoded);
      const maxSide = 2200;
      final longestSide = math.max(image.width, image.height);

      if (longestSide > maxSide) {
        final scale = maxSide / longestSide;
        image = img.copyResize(
          image,
          width: math.max(1, (image.width * scale).round()),
          height: math.max(1, (image.height * scale).round()),
        );
      }

      return Uint8List.fromList(
        img.encodeJpg(image, quality: 84),
      );
    } catch (_) {
      return bytes;
    }
  }

  Future<void> _uploadBytes({
    required Reference storageRef,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    await _uploadBytesWithRetry(
      storageRef: storageRef,
      imageBytes: imageBytes,
      mimeType: mimeType,
    );
  }

  Future<void> _uploadBytesWithRetry({
    required Reference storageRef,
    required Uint8List imageBytes,
    required String mimeType,
    int maxAttempts = 3,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await storageRef
            .putData(
              imageBytes,
              SettableMetadata(
                contentType: mimeType,
                cacheControl: 'public,max-age=31536000',
              ),
            )
            .timeout(const Duration(seconds: 90));
        return;
      } catch (error) {
        lastError = error;

        if (attempt < maxAttempts) {
          await Future<void>.delayed(
            Duration(seconds: attempt * 2),
          );
        }
      }
    }

    throw StateError(
      'Photo upload failed after $maxAttempts attempts '
      '(${storageRef.fullPath}). Last error: $lastError',
    );
  }

  Future<String> _downloadUrl(Reference storageRef) {
    return _downloadUrlWithRetry(storageRef);
  }

  Future<String> _downloadUrlWithRetry(
    Reference storageRef, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await storageRef
            .getDownloadURL()
            .timeout(const Duration(seconds: 30));
      } catch (error) {
        lastError = error;

        if (attempt < maxAttempts) {
          await Future<void>.delayed(
            Duration(seconds: attempt * 2),
          );
        }
      }
    }

    throw StateError(
      'Could not get photo URL after $maxAttempts attempts '
      '(${storageRef.fullPath}). Last error: $lastError',
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

  String? _normalizeExpiryDateText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;

    final normalized =
        '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';

    return normalized == text ? normalized : null;
  }

  DateTime? _parseExpiryDate(String? value) {
    final normalized = _normalizeExpiryDateText(value);
    if (normalized == null) return null;
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
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
