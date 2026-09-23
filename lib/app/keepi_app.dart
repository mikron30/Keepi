import 'package:flutter/material.dart';

import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_preference.dart';
import '../features/auth/presentation/auth_gate.dart';

class KeepiApp extends StatefulWidget {
  const KeepiApp({super.key});

  @override
  State<KeepiApp> createState() => _KeepiAppState();
}

class _KeepiAppState extends State<KeepiApp> {
  @override
  void initState() {
    super.initState();

    // Never delay the first Flutter frame for local preferences.
    ThemePreference.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemePreference.notifier,
      builder: (context, themeMode, _) {
        return MaterialApp.router(
          title: 'Keepi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: appRouter,
          builder: (context, child) {
            return AuthGate(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
