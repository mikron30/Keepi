import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/thing_repository.dart';
import '../domain/thing.dart';

class CategoryThingsScreen extends StatelessWidget {
  const CategoryThingsScreen({
    required this.categoryId,
    super.key,
  });

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final repository = ThingRepository();

    return Scaffold(
      appBar: AppBar(
        title: Text(_categoryLabel(categoryId)),
      ),
      body: StreamBuilder<List<Thing>>(
        stream: repository.watchMyThings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this folder: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final things = snapshot.data!
              .where((thing) => thing.categoryId == categoryId)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(
                    b.name.toLowerCase(),
                  ),
            );

          if (things.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'This folder is empty.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            itemCount: things.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final thing = things[index];

              return _CompactThingTile(
                thing: thing,
                onTap: () => context.push('/things/${thing.id}'),
              );
            },
          );
        },
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

class _CompactThingTile extends StatelessWidget {
  const _CompactThingTile({
    required this.thing,
    required this.onTap,
  });

  final Thing thing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = thing.thumbnailUrl?.trim().isNotEmpty == true
        ? thing.thumbnailUrl!.trim()
        : (thing.photoUrls.isEmpty ? null : thing.photoUrls.first);

    final description = thing.description?.trim() ?? '';
    final subtitle = description.isNotEmpty
        ? description
        : (thing.subcategoryId?.trim().isNotEmpty == true
            ? thing.subcategoryId!.trim()
            : 'Tap to view product');

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: thumbnailUrl == null
                      ? const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.inventory_2_outlined),
                        )
                      : Image.network(
                          thumbnailUrl,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
