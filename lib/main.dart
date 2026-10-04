import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/keepi_app.dart';
import 'core/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await FirebaseBootstrap.tryInitialize();

  runApp(
    ProviderScope(
      child: firebaseReady
          ? const KeepiApp()
          : _KeepiStartupError(
              details: FirebaseBootstrap.lastError,
            ),
    ),
  );
}

class _KeepiStartupError extends StatelessWidget {
  const _KeepiStartupError({
    required this.details,
  });

  final String? details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 56),
                    const SizedBox(height: 20),
                    Text(
                      'Keepi could not connect',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please check your internet connection and open Keepi again.',
                      textAlign: TextAlign.center,
                    ),
                    if (details != null && details!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('Technical details'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              details!,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
