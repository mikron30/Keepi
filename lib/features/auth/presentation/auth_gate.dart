import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

        return widget.child;
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
