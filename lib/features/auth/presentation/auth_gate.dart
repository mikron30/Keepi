import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../data/auth_service.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initializing = true;
  bool _firebaseReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      final ready = await FirebaseBootstrap.tryInitialize().timeout(
        const Duration(seconds: 12),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _firebaseReady = ready;
        _initializing = false;
        if (!ready) {
          _error = 'Firebase configuration could not be loaded.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _firebaseReady = false;
        _initializing = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const _KeepiStartingScreen();
    }

    if (!_firebaseReady) {
      return _FirebaseNotReadyScreen(
        error: _error,
        onRetry: () {
          setState(() {
            _initializing = true;
            _error = null;
          });
          _initializeFirebase();
        },
      );
    }

    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _KeepiStartingScreen();
        }

        if (snapshot.data == null) {
          return const AuthScreen();
        }

        return _TermsGate(
          user: snapshot.data!,
          child: widget.child,
        );
      },
    );
  }
}

class _KeepiStartingScreen extends StatelessWidget {
  const _KeepiStartingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/keepi_icon.png',
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Keepi',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 18),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirebaseNotReadyScreen extends StatelessWidget {
  const _FirebaseNotReadyScreen({
    required this.onRetry,
    this.error,
  });

  final VoidCallback onRetry;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 72),
                  const SizedBox(height: 20),
                  Text(
                    'Firebase is not connected',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Keepi started correctly, but Firebase could not initialize.',
                    textAlign: TextAlign.center,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _TermsGate extends StatefulWidget {
  const _TermsGate({
    required this.user,
    required this.child,
  });

  final User user;
  final Widget child;

  @override
  State<_TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends State<_TermsGate> {
  static final _termsUri = Uri.parse(
    'https://keepi.web.app/app/terms.html',
  );

  bool _agreed = false;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

  Future<void> _openTerms() async {
    await launchUrl(_termsUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _accept() async {
    if (!_agreed || _saving) return;

    setState(() => _saving = true);
    try {
      await _profileRef.set({
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': '2026-10-03',
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data != null && data['termsAcceptedAt'] != null) {
          return widget.child;
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Keepi community rules',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Before using Keepi, please accept the Terms of Use. '
                            'Keepi does not allow illegal, abusive, deceptive, '
                            'harassing or otherwise objectionable content or behavior.',
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _openTerms,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Read Terms of Use'),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _agreed,
                            onChanged: _saving
                                ? null
                                : (value) =>
                                    setState(() => _agreed = value ?? false),
                            title: const Text(
                              'I agree to the Keepi Terms of Use',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _agreed && !_saving ? _accept : null,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Continue to Keepi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
