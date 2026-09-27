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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Things'),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.go('/explore'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Add a Thing',
            onPressed: () => context.go('/add'),
            icon: const Icon(Icons.add_circle_outline),
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
            return _EmptyState(onAdd: () => context.go('/add'));
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
            color: scheme.primary,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Text(
                  'Organized by category',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${things.length} Things · ${categories.length} folders',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.93,
                  ),
                  itemBuilder: (context, index) {
                    final categoryId = categories[index];
                    final categoryThings = grouped[categoryId]!;

                    return _CategoryFolderCard(
                      categoryId: categoryId,
                      things: categoryThings,
                      onTap: () => context.push(
                        '/things/category/${Uri.encodeComponent(categoryId)}',
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add a Thing',
        onPressed: () => context.go('/add'),
        child: const Icon(Icons.add),
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
        return 'Sports & Outdoor';
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
        return _prettyCategory(value);
    }
  }

  static String _prettyCategory(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
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
    final scheme = Theme.of(context).colorScheme;
    final previewUrl = _previewUrl();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (previewUrl != null)
                    Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy:
                          WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) => _FallbackPreview(
                        categoryId: categoryId,
                      ),
                    )
                  else
                    _FallbackPreview(categoryId: categoryId),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 9, 11),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _categoryIcon(categoryId),
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _MyThingsScreenState._categoryLabel(categoryId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${things.length} ${things.length == 1 ? 'item' : 'items'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _previewUrl() {
    for (final thing in things) {
      if (thing.thumbnailUrl?.trim().isNotEmpty == true) {
        return thing.thumbnailUrl!.trim();
      }
      if (thing.photoUrls.isNotEmpty) {
        return thing.photoUrls.first;
      }
    }
    return null;
  }

  static IconData _categoryIcon(String value) {
    switch (value) {
      case 'books':
        return Icons.menu_book_outlined;
      case 'food':
        return Icons.restaurant_outlined;
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
        return Icons.chair_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}

class _FallbackPreview extends StatelessWidget {
  const _FallbackPreview({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _CategoryFolderCard._categoryIcon(categoryId),
          color: scheme.primary,
          size: 48,
        ),
      ),
    );
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
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photograph your first Thing and Keepi will organize it '
              'automatically.',
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
        child: Text(
          'Could not load My Things\n\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
