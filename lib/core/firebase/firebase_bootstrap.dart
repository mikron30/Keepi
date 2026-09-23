import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool> tryInitialize() async {
    try {
      await Firebase.initializeApp();
      return true;
    } catch (_) {
      // Keep the UI runnable before flutterfire configure is completed.
      return false;
    }
  }
}
