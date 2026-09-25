import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/thing_repository.dart';
import '../domain/thing.dart';

class MyThingsScreen extends StatefulWidget {
  const MyThingsScreen({super.key});

  @override
  State<MyThingsScreen> createState() => _MyThingsScreenState();
}

class _MyThingsScreenState extends State<MyThingsScreen> {
  late final ThingRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ThingRepository();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Things'),
        actions: [
          IconButton(
            tooltip: 'Add a Thing',
            onPressed: () => context.go('/add'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<Thing>>(
        stream: _repository.watchMyThings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final things = snapshot.data!;
          if (things.isEmpty) {
            return _EmptyState(
              onAdd: () => context.go('/add'),
            );
          }

          final grouped = <String, List<Thing>>{};
          for (final thing in things) {
            grouped.putIfAbsent(thing.categoryId, () => []).add(thing);
          }

          final categories = grouped.keys.toList()
            ..sort(
              (a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)),
            );

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: [
                Text(
                  '${things.length} Things in ${categories.length} folders',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ...categories.map((categoryId) {
                  final categoryThings = grouped[categoryId]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CategoryFolderCard(
                      categoryId: categoryId,
                      things: categoryThings,
                      onTap: () => context.push(
                        '/things/category/$categoryId',
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/add'),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Add'),
      ),
    );
  }

  static String _categoryLabel(String value) {
    switch (value) {
      case 'home':
        return 'Home';
      case 'vehicles':
        return 'Vehicles';
      case 'tools':
        return 'Tools';
      case 'sports':
        return 'Sports';
      case 'garden':
        return 'Garden';
      case 'electronics':
        return 'Electronics';
      case 'food':
        return 'Food';
      case 'drinks':
        return 'Drinks';
      case 'books':
        return 'Books';
      case 'clothing':
        return 'Clothing';
      case 'baby':
        return 'Baby';
      case 'camping':
        return 'Camping';
      case 'real_estate':
        return 'Real estate';
      case 'personal_care':
        return 'Personal care';
      default:
        return 'Other';
    }
  }
}

class _CategoryFolderCard extends StatelessWidget {
  const _CategoryFolderCard({
    required this.categoryId,
    required this.things,
    required this.onTap,
  });

  final String categoryId;
  final List<Thing> things;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previews = things
        .map((thing) {
          if (thing.thumbnailUrl?.trim().isNotEmpty == true) {
            return thing.thumbnailUrl!.trim();
          }
          if (thing.photoUrls.isNotEmpty) {
            return thing.photoUrls.first;
          }
          return null;
        })
        .whereType<String>()
        .take(3)
        .toList();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _FolderPreview(
                categoryId: categoryId,
                previewUrls: previews,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _MyThingsScreenState._categoryLabel(categoryId),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${things.length} ${things.length == 1 ? 'Thing' : 'Things'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderPreview extends StatelessWidget {
  const _FolderPreview({
    required this.categoryId,
    required this.previewUrls,
  });

  final String categoryId;
  final List<String> previewUrls;

  @override
  Widget build(BuildContext context) {
    if (previewUrls.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          _categoryIcon(categoryId),
          size: 36,
        ),
      );
    }

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          for (var index = 0; index < previewUrls.length; index++)
            Positioned(
              left: index * 10,
              top: index * 6,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  previewUrls[index],
                  fit: BoxFit.cover,
                  webHtmlElementStrategy:
                      WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Icon(_categoryIcon(categoryId)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String value) {
    switch (value) {
      case 'books':
        return Icons.menu_book_outlined;
      case 'food':
        return Icons.kitchen_outlined;
      case 'drinks':
        return Icons.local_drink_outlined;
      case 'tools':
        return Icons.handyman_outlined;
      case 'electronics':
        return Icons.devices_other_outlined;
      case 'sports':
        return Icons.sports_tennis_outlined;
      case 'garden':
        return Icons.yard_outlined;
      case 'vehicles':
        return Icons.directions_car_outlined;
      case 'clothing':
        return Icons.checkroom_outlined;
      case 'baby':
        return Icons.child_care_outlined;
      case 'camping':
        return Icons.terrain_outlined;
      case 'real_estate':
        return Icons.apartment_outlined;
      case 'personal_care':
        return Icons.spa_outlined;
      case 'home':
        return Icons.home_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 72),
            const SizedBox(height: 18),
            Text(
              'Nothing here yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photograph your first Thing and Keepi will file it '
              'automatically in the right folder.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Add a Thing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Could not load My Things',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
