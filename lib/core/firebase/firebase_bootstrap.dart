import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _measurementId =
      String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

  // reCAPTCHA Enterprise site keys are public client-side identifiers.
  static const _webRecaptchaEnterpriseSiteKey =
      '6LfKk8stAAAAAKqQJ8qXzXGHrDS_axX_VJa8_vBR';

  static Future<bool> tryInitialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        final hasExplicitOptions = _apiKey.isNotEmpty &&
            _appId.isNotEmpty &&
            _messagingSenderId.isNotEmpty &&
            _projectId.isNotEmpty;

        if (hasExplicitOptions) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _messagingSenderId,
              projectId: _projectId,
              authDomain: _authDomain.isEmpty ? null : _authDomain,
              storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
              measurementId: _measurementId.isEmpty ? null : _measurementId,
            ),
          );
        } else if (kIsWeb) {
          return false;
        } else {
          // Supports a locally generated google-services.json /
          // GoogleService-Info.plist when present.
          await Firebase.initializeApp();
        }
      }

      if (kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaEnterpriseProvider(
            _webRecaptchaEnterpriseSiteKey,
          ),
        );
      }

      return true;
    } catch (error) {
      debugPrint('Firebase bootstrap failed: $error');
      return false;
    }
  }
}
