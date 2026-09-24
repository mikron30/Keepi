import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../chat/data/chat_repository.dart';
import '../../inventory/data/thing_repository.dart';
import '../../inventory/domain/thing.dart';
import '../../profile/data/user_profile_repository.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _repository = ThingRepository();
  final _profileRepository = UserProfileRepository();
  final _chatRepository = ChatRepository();
  final _searchController = TextEditingController();

  Map<String, double>? _searchLocation;
  bool _loadingLocation = true;
  bool _startingChat = false;
  double _radiusKm = 25;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedLocation() async {
    try {
      final location = await _profileRepository.getPreferredSearchLocation();
      if (mounted) {
        setState(() {
          _searchLocation = location;
          _loadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);

    try {
      final position = await LocationService.getCurrentPosition();
      await _profileRepository.saveCurrentLocation(position);

      if (!mounted) return;

      setState(() {
        _searchLocation = {
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
        _loadingLocation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _messageOwner(Thing thing) async {
    if (_startingChat) return;

    setState(() => _startingChat = true);

    try {
      final conversationId = await _chatRepository.ensureConversation(
        otherUserId: thing.ownerId,
        otherDisplayName: thing.ownerDisplayName,
        thingId: thing.id,
        thingName: thing.name,
      );

      if (mounted) {
        context.push('/messages/${conversationId}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: ${error}')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.push('/messages'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: StreamBuilder<List<Thing>>(
        stream: _repository.watchPublicThings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load nearby Things: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final things = snapshot.data ?? const <Thing>[];
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final query = _searchController.text.trim().toLowerCase();

          final results = things
              .where((thing) => thing.ownerId != currentUid)
              .where((thing) {
                if (query.isEmpty) return true;
                final haystack = [
                  thing.name,
                  thing.categoryId,
                  thing.subcategoryId ?? '',
                  ...thing.searchKeywords,
                ].join(' ').toLowerCase();
                return haystack.contains(query);
              })
              .map((thing) {
                final distance = _distanceKm(thing);
                return _NearbyThing(thing: thing, distanceKm: distance);
              })
              .where((entry) {
                if (_searchLocation == null) return true;
                if (entry.distanceKm == null) return false;
                return entry.distanceKm! <= _radiusKm;
              })
              .toList()
            ..sort((a, b) {
              final da = a.distanceKm ?? double.infinity;
              final db = b.distanceKm ?? double.infinity;
              return da.compareTo(db);
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search for anything nearby...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.near_me_outlined),
                      title: Text(
                        _searchLocation == null
                            ? 'Set a location for nearby search'
                            : 'Searching near your saved location',
                      ),
                      subtitle: Text(
                        _searchLocation == null
                            ? 'Use current location, or save Home in Profile.'
                            : 'Exact home/current coordinates remain private.',
                      ),
                      trailing: _loadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: _useCurrentLocation,
                              child: const Text('Update'),
                            ),
                    ),
                    if (_searchLocation != null) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Text('Radius'),
                            Expanded(
                              child: Slider(
                                value: _radiusKm,
                                min: 1,
                                max: 100,
                                divisions: 99,
                                label: '${_radiusKm.round()} km',
                                onChanged: (value) {
                                  setState(() => _radiusKm = value);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 58,
                              child: Text(
                                '${_radiusKm.round()} km',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${results.length} nearby Things',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              if (!snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (results.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nothing matches yet. Try a larger radius or another search.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...results.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PublicThingCard(
                      entry: entry,
                      onMessage: () => _messageOwner(entry.thing),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double? _distanceKm(Thing thing) {
    final location = _searchLocation;
    final latitude = thing.latitude;
    final longitude = thing.longitude;

    if (location == null || latitude == null || longitude == null) {
      return null;
    }

    return Geolocator.distanceBetween(
          location['latitude']!,
          location['longitude']!,
          latitude,
          longitude,
        ) /
        1000;
  }
}

class _NearbyThing {
  const _NearbyThing({
    required this.thing,
    required this.distanceKm,
  });

  final Thing thing;
  final double? distanceKm;
}

class _PublicThingCard extends StatelessWidget {
  const _PublicThingCard({
    required this.entry,
    required this.onMessage,
  });

  final _NearbyThing entry;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final thing = entry.thing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 82,
                height: 82,
                child: thing.photoUrls.isEmpty
                    ? const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.inventory_2_outlined),
                      )
                    : Image.network(
                        thing.photoUrls.first,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy:
                            WebHtmlElementStrategy.fallback,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thing.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      thing.ownerDisplayName,
                      if (entry.distanceKm != null)
                        '${entry.distanceKm!.toStringAsFixed(1)} km away',
                    ].join(' · '),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: thing.enabledActions
                        .where((action) => action != ThingAction.personalUse)
                        .map(
                          (action) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(_label(action)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Message owner'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(ThingAction action) {
    switch (action) {
      case ThingAction.personalUse:
        return 'Personal';
      case ThingAction.sell:
        return 'For sale';
      case ThingAction.rent:
        return 'For rent';
      case ThingAction.borrow:
        return 'For loan';
      case ThingAction.give:
        return 'Free';
      case ThingAction.exchange:
        return 'Exchange';
    }
  }
}
