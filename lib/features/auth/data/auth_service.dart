import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static bool _googleInitialized = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await _ensureUserProfile(credential.user);
    return credential;
  }

  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null && name.trim().isNotEmpty) {
      await user.updateDisplayName(name.trim());
      await user.reload();
    }

    await _ensureUserProfile(
      _auth.currentUser,
      preferredName: name.trim(),
    );

    return credential;
  }

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({
        'prompt': 'select_account',
      });

    if (kIsWeb) {
      // Popup avoids the cross-origin redirect persistence problem on web.app.
      final credential = await _auth.signInWithPopup(provider);
      await _ensureUserProfile(credential.user);
      return;
    }

    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'google-token-missing',
        message: 'Google did not return an ID token.',
      );
    }

    final googleCredential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final credential = await _auth.signInWithCredential(googleCredential);
    await _ensureUserProfile(credential.user);
  }

  Future<void> signInWithApple() async {
    final provider = AppleAuthProvider();

    if (kIsWeb) {
      final credential = await _auth.signInWithPopup(provider);
      await _ensureUserProfile(credential.user);
      return;
    }

    final credential = await _auth.signInWithProvider(provider);
    await _ensureUserProfile(credential.user);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb && _googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign-out already completed.
      }
    }
  }

  Future<void> ensureCurrentUserProfile() async {
    await _ensureUserProfile(_auth.currentUser);
  }

  Future<void> _ensureUserProfile(
    User? user, {
    String? preferredName,
  }) async {
    if (user == null) {
      return;
    }

    final reference = _firestore.collection('users').doc(user.uid);
    final existing = await reference.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'displayName': preferredName?.isNotEmpty == true
          ? preferredName
          : user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'providers': user.providerData.map((provider) => provider.providerId).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await reference.set(data, SetOptions(merge: true));
  }
}
