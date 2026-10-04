import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidSigningInfo {
  AndroidSigningInfo._();

  static const MethodChannel _channel =
      MethodChannel('com.mikron30.keepi/native');

  static Future<String?> sha1() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('signingSha1');
    } catch (_) {
      return null;
    }
  }
}
