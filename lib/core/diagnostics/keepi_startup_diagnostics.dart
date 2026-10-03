import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_bootstrap.dart';
import '../runtime/keepi_runtime.dart';

class DiagnosticEntry {
  DiagnosticEntry({
    required this.name,
    required this.status,
    required this.details,
  });

  final String name;
  final String status;
  final String details;

  bool get ok => status == 'PASS';
}

class KeepiDiagnostics {
  KeepiDiagnostics._();

  static final KeepiDiagnostics instance = KeepiDiagnostics._();

  final ValueNotifier<String?> fatalReport = ValueNotifier<String?>(null);
  final List<DiagnosticEntry> entries = <DiagnosticEntry>[];

  void captureFatal(
    Object error,
    StackTrace stack, {
    String source = 'Dart',
  }) {
    final report = StringBuffer()
      ..writeln('KEEPI FATAL ERROR')
      ..writeln('Source: $source')
      ..writeln('Time: ${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln(error)
      ..writeln()
      ..writeln(stack);

    fatalReport.value = report.toString();
  }

  Future<void> runChecks({
    required void Function() onUpdated,
  }) async {
    entries.clear();
    onUpdated();

    Future<void> check(
      String name,
      Future<String> Function() test,
    ) async {
      try {
        final details = await test().timeout(const Duration(seconds: 12));
        entries.add(
          DiagnosticEntry(
            name: name,
            status: 'PASS',
            details: details,
          ),
        );
      } catch (error, stack) {
        entries.add(
          DiagnosticEntry(
            name: name,
            status: 'FAIL',
            details: '$error\n$stack',
          ),
        );
      }
      onUpdated();
    }

    await check('Flutter runtime', () async {
      return 'Flutter binding is active on '
          '${defaultTargetPlatform.name}.';
    });

    await check('Package information', () async {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.appName} '
          '${packageInfo.version}+${packageInfo.buildNumber} '
          '(${packageInfo.packageName})';
    });

    await check('SharedPreferences', () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'keepi_diagnostic_ping',
        DateTime.now().toIso8601String(),
      );
      final readBack = preferences.getString('keepi_diagnostic_ping');
      if (readBack == null) {
        throw StateError('SharedPreferences write/read verification failed.');
      }
      return 'Local storage read/write works.';
    });

    await check('Firebase Core', () async {
      final ready = await FirebaseBootstrap.tryInitialize();
      if (!ready) {
        throw StateError(
          FirebaseBootstrap.lastError ??
              'Firebase initialization returned false.',
        );
      }
      return 'Firebase initialized successfully.';
    });

    if (FirebaseBootstrap.isReady) {
      await check('Firebase Authentication', () async {
        final auth = FirebaseAuth.instance;
        final user = auth.currentUser;
        return user == null
            ? 'Firebase Auth works. No user is currently signed in.'
            : 'Firebase Auth works. Signed in as ${user.email ?? user.uid}.';
      });

      await check('Cloud Firestore', () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return 'Firestore client created. Sign in to test an authenticated read.';
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));
        return 'Authenticated Firestore read works.';
      });
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await check('AdMob consent API', () async {
        final completer = Completer<void>();
        ConsentInformation.instance.requestConsentInfoUpdate(
          ConsentRequestParameters(),
          () {
            if (!completer.isCompleted) completer.complete();
          },
          (formError) {
            if (!completer.isCompleted) {
              completer.completeError(
                StateError(
                  'Consent update failed: '
                  '${formError.errorCode}: ${formError.message}',
                ),
              );
            }
          },
        );
        await completer.future;
        final canRequestAds =
            await ConsentInformation.instance.canRequestAds();
        return 'UMP responded. canRequestAds=$canRequestAds';
      });
    }
  }

  String buildReport() {
    final buffer = StringBuffer()
      ..writeln('KEEPI STARTUP DIAGNOSTIC REPORT')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Safe mode: ${KeepiRuntime.diagnosticSafeMode}')
      ..writeln();

    for (final entry in entries) {
      buffer
        ..writeln('[${entry.status}] ${entry.name}')
        ..writeln(entry.details)
        ..writeln();
    }

    final fatal = fatalReport.value;
    if (fatal != null) {
      buffer
        ..writeln('--- FATAL REPORT ---')
        ..writeln(fatal);
    }

    return buffer.toString();
  }
}

class KeepiDiagnosticRoot extends StatefulWidget {
  const KeepiDiagnosticRoot({
    required this.app,
    super.key,
  });

  final Widget app;

  @override
  State<KeepiDiagnosticRoot> createState() => _KeepiDiagnosticRootState();
}

class _KeepiDiagnosticRootState extends State<KeepiDiagnosticRoot> {
  final diagnostics = KeepiDiagnostics.instance;

  bool _running = true;
  bool _continueToApp = false;

  @override
  void initState() {
    super.initState();
    diagnostics.fatalReport.addListener(_fatalChanged);
    _run();
  }

  @override
  void dispose() {
    diagnostics.fatalReport.removeListener(_fatalChanged);
    super.dispose();
  }

  void _fatalChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run() async {
    setState(() => _running = true);
    await diagnostics.runChecks(
      onUpdated: () {
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() => _running = false);
  }

  void _startApp({required bool safeMode}) {
    KeepiRuntime.diagnosticSafeMode = safeMode;
    diagnostics.fatalReport.value = null;
    setState(() => _continueToApp = true);
  }

  @override
  Widget build(BuildContext context) {
    final fatal = diagnostics.fatalReport.value;
    if (fatal != null) {
      return _CrashReportScreen(
        report: diagnostics.buildReport(),
        onBackToDiagnostics: () {
          diagnostics.fatalReport.value = null;
          setState(() => _continueToApp = false);
        },
      );
    }

    if (_continueToApp) {
      return widget.app;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFF634D),
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Keepi Startup Diagnostics'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Keepi is running self-tests on this phone. '
                'No USB connection is required.',
              ),
              const SizedBox(height: 16),
              for (final entry in diagnostics.entries)
                Card(
                  child: ExpansionTile(
                    leading: Icon(
                      entry.ok ? Icons.check_circle : Icons.error,
                      color: entry.ok ? Colors.greenAccent : Colors.redAccent,
                    ),
                    title: Text('${entry.status} · ${entry.name}'),
                    subtitle: Text(
                      entry.details.split('\n').first,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(entry.details),
                      ),
                    ],
                  ),
                ),
              if (_running) ...[
                const SizedBox(height: 18),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 8),
                const Center(child: Text('Running tests...')),
              ] else ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _startApp(safeMode: false),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Keepi normally'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _startApp(safeMode: true),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Start in safe mode (no ads)'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Run tests again'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: diagnostics.buildReport()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostic report copied.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy full report'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CrashReportScreen extends StatelessWidget {
  const _CrashReportScreen({
    required this.report,
    required this.onBackToDiagnostics,
  });

  final String report;
  final VoidCallback onBackToDiagnostics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFF634D),
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Keepi caught an error'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Keepi caught a Dart/Flutter startup error instead of '
                'closing silently. Copy the report and send it in the chat.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  report,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: report));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy report'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onBackToDiagnostics,
                child: const Text('Back to diagnostics'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
