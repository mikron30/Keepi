import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/keepi_app.dart';
import 'core/diagnostics/keepi_startup_diagnostics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final diagnostics = KeepiDiagnostics.instance;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    diagnostics.captureFatal(
      details.exception,
      details.stack ?? StackTrace.current,
      source: 'FlutterError',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    diagnostics.captureFatal(
      error,
      stack,
      source: 'PlatformDispatcher',
    );
    return true;
  };

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          child: KeepiDiagnosticRoot(
            app: const KeepiApp(),
          ),
        ),
      );
    },
    (error, stack) {
      diagnostics.captureFatal(
        error,
        stack,
        source: 'runZonedGuarded',
      );
    },
  );
}
