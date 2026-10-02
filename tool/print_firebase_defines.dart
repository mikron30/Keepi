// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:io';

void main(List<String> args) {
  if (args.length != 1 || !const {'android', 'ios', 'web'}.contains(args.first)) {
    stderr.writeln('Usage: dart run tool/print_firebase_defines.dart <android|ios|web>');
    exitCode = 2;
    return;
  }

  final file = File('lib/firebase_options.dart');
  if (!file.existsSync()) {
    stderr.writeln(
      'Missing lib/firebase_options.dart. Run flutterfire configure for Keepi first.',
    );
    exitCode = 3;
    return;
  }

  final platform = args.first;
  final content = file.readAsStringSync();
  final block = RegExp(
    r'static const FirebaseOptions\s+' +
        RegExp.escape(platform) +
        r'\s*=\s*FirebaseOptions\((.*?)\n\s*\);',
    dotAll: true,
  ).firstMatch(content);

  if (block == null) {
    stderr.writeln('Firebase options for ' + platform + ' were not found.');
    exitCode = 4;
    return;
  }

  final body = block.group(1)!;
  const mapping = <String, String>{
    'apiKey': 'FIREBASE_API_KEY',
    'appId': 'FIREBASE_APP_ID',
    'messagingSenderId': 'FIREBASE_MESSAGING_SENDER_ID',
    'projectId': 'FIREBASE_PROJECT_ID',
    'authDomain': 'FIREBASE_AUTH_DOMAIN',
    'storageBucket': 'FIREBASE_STORAGE_BUCKET',
    'measurementId': 'FIREBASE_MEASUREMENT_ID',
  };

  var requiredFound = 0;

  for (final entry in mapping.entries) {
    final match = RegExp(entry.key + r"\s*:\s*'([^']*)'").firstMatch(body);
    final value = match?.group(1);
    if (value == null || value.isEmpty) {
      continue;
    }

    if (const {
      'apiKey',
      'appId',
      'messagingSenderId',
      'projectId',
    }.contains(entry.key)) {
      requiredFound++;
    }

    stdout.writeln('--dart-define=' + entry.value + '=' + value);
  }

  if (requiredFound != 4) {
    stderr.writeln(
      'Incomplete Firebase options for ' + platform +
          '. Run flutterfire configure again.',
    );
    exitCode = 5;
  }
}
