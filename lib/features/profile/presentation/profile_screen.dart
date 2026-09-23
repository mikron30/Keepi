import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseReady = ref.watch(firebaseReadyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('Keepi user'),
              subtitle: Text('Authentication comes after Firebase configuration.'),
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
                    ? 'Firebase is initialized.'
                    : 'Not configured on this device yet.',
              ),
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
        ],
      ),
    );
  }
}
