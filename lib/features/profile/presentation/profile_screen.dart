import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/theme/theme_preference.dart';
import '../../auth/data/auth_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null
                    ? Text(_initialFor(user))
                    : null,
              ),
              title: Text(
                user?.displayName?.trim().isNotEmpty == true
                    ? user!.displayName!
                    : 'Keepi user',
              ),
              subtitle: Text(user?.email ?? 'Signed in'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                firebaseReady
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
              ),
              title: const Text('Firebase'),
              subtitle: Text(
                firebaseReady
                    ? 'Connected to Keepi.'
                    : 'Not configured on this device yet.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemePreference.notifier,
              builder: (context, themeMode, _) {
                final platformDark =
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark;
                final isDark = themeMode == ThemeMode.dark ||
                    (themeMode == ThemeMode.system && platformDark);

                return SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Use a darker Keepi theme'),
                  value: isDark,
                  onChanged: ThemePreference.setDarkMode,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Transactions'),
                  trailing: Icon(Icons.chevron_right),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.star_outline),
                  title: Text('Reviews'),
                  trailing: Icon(Icons.chevron_right),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await AuthService().signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _initialFor(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }

    return 'K';
  }
}
