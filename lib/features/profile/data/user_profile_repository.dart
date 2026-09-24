import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class UserProfileRepository {
  UserProfileRepository({
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

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      _firestore.collection('users').doc(_user.uid);

  Stream<Map<String, dynamic>> watchProfile() {
    return _profileRef.snapshots().map(
          (snapshot) => snapshot.data() ?? <String, dynamic>{},
        );
  }

  Future<Map<String, dynamic>> getProfile() async {
    return (await _profileRef.get()).data() ?? <String, dynamic>{};
  }

  Future<void> savePhoneNumber(String phoneNumber) async {
    await _profileRef.set({
      'phoneNumber': phoneNumber.trim(),
      'phoneVisibleToOthers': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveHomeLocation(Position position) async {
    await _profileRef.set({
      'homeLocation': _locationMap(position),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveCurrentLocation(Position position) async {
    await _profileRef.set({
      'currentLocation': _locationMap(position),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, double>?> getPreferredSearchLocation() async {
    final profile = await getProfile();

    final current = _readLocation(profile['currentLocation']);
    if (current != null) {
      return current;
    }

    return _readLocation(profile['homeLocation']);
  }

  Future<Map<String, double>?> getHomeLocation() async {
    final profile = await getProfile();
    return _readLocation(profile['homeLocation']);
  }

  Future<Map<String, double>?> getCurrentSavedLocation() async {
    final profile = await getProfile();
    return _readLocation(profile['currentLocation']);
  }

  Map<String, dynamic> _locationMap(Position position) {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracy,
      'updatedAt': Timestamp.now(),
    };
  }

  Map<String, double>? _readLocation(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final latitude = value['latitude'];
    final longitude = value['longitude'];

    if (latitude is! num || longitude is! num) {
      return null;
    }

    return {
      'latitude': latitude.toDouble(),
      'longitude': longitude.toDouble(),
    };
  }
}
