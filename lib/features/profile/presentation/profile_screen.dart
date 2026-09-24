import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/theme_preference.dart';
import '../../auth/data/auth_service.dart';
import '../data/user_profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final UserProfileRepository _profileRepository;
  bool _savingLocation = false;

  @override
  void initState() {
    super.initState();
    _profileRepository = UserProfileRepository();
  }

  Future<void> _editPhone(String currentPhone) async {
    final controller = TextEditingController(text: currentPhone);

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Phone number'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '+972...',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null || value.trim().isEmpty) {
      return;
    }

    try {
      await _profileRepository.savePhoneNumber(value);
      _showMessage('Phone number saved privately.');
    } catch (error) {
      _showMessage('Could not save phone number: $error');
    }
  }

  Future<void> _saveLocation({required bool asHome}) async {
    if (_savingLocation) {
      return;
    }

    setState(() => _savingLocation = true);

    try {
      final position = await LocationService.getCurrentPosition();

      if (asHome) {
        await _profileRepository.saveHomeLocation(position);
        _showMessage('Home location saved.');
      } else {
        await _profileRepository.saveCurrentLocation(position);
        _showMessage('Current location updated.');
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _savingLocation = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: firebaseReady ? _profileRepository.watchProfile() : null,
        builder: (context, snapshot) {
          final profile = snapshot.data ?? const <String, dynamic>{};
          final phone = (profile['phoneNumber'] ?? '').toString();
          final homeLocation = profile['homeLocation'];
          final currentLocation = profile['currentLocation'];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null ? Text(_initialFor(user)) : null,
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
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Phone number'),
                      subtitle: Text(
                        phone.isEmpty
                            ? 'Not added yet'
                            : '$phone · private by default',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: firebaseReady ? () => _editPhone(phone) : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Home location'),
                      subtitle: Text(
                        _locationStatus(
                          homeLocation,
                          empty: 'Not saved yet',
                        ),
                      ),
                      trailing: _savingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      onTap: firebaseReady && !_savingLocation
                          ? () => _saveLocation(asHome: true)
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.near_me_outlined),
                      title: const Text('Current location'),
                      subtitle: Text(
                        _locationStatus(
                          currentLocation,
                          empty: 'Tap to update when you want nearby results',
                        ),
                      ),
                      trailing: _savingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      onTap: firebaseReady && !_savingLocation
                          ? () => _saveLocation(asHome: false)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exact home/current coordinates stay in your private profile. '
                'Nearby search uses the location attached to each public Thing.',
                style: Theme.of(context).textTheme.bodySmall,
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
                        MediaQuery.platformBrightnessOf(context) ==
                            Brightness.dark;
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
                onPressed: firebaseReady
                    ? () async {
                        await AuthService().signOut();
                      }
                    : null,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _locationStatus(dynamic value, {required String empty}) {
    if (value is! Map) {
      return empty;
    }

    final updatedAt = value['updatedAt'];
    if (updatedAt is Timestamp) {
      final date = updatedAt.toDate();
      final local = date.toLocal();
      final day = local.day.toString().padLeft(2, '0');
      final month = local.month.toString().padLeft(2, '0');
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return 'Saved · $day/$month $hour:$minute';
    }

    return 'Saved';
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
