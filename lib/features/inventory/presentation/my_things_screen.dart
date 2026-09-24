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

  Future<void> _markLent(Thing thing) async {
    final controller = TextEditingController();

    final borrowerName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Who has ${thing.name}?'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Borrower / holder name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) Navigator.pop(context, name);
              },
              child: const Text('Mark as lent'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (borrowerName == null || borrowerName.isEmpty) return;

    try {
      await _repository.markThingLent(
        thingId: thing.id,
        borrowerName: borrowerName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${thing.name} is now with $borrowerName.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update loan: $error')),
        );
      }
    }
  }

  Future<void> _markReturned(Thing thing) async {
    try {
      await _repository.markThingReturned(thing.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${thing.name} marked as returned.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark returned: $error')),
        );
      }
    }
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
            return _ErrorState(
              message: snapshot.error.toString(),
            );
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

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 350));
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              itemCount: things.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _ThingCard(
                  thing: things[index],
                  onMarkLent: () => _markLent(things[index]),
                  onMarkReturned: () => _markReturned(things[index]),
                );
              },
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
}

class _ThingCard extends StatelessWidget {
  const _ThingCard({
    required this.thing,
    required this.onMarkLent,
    required this.onMarkReturned,
  });

  final Thing thing;
  final VoidCallback onMarkLent;
  final VoidCallback onMarkReturned;

  @override
  Widget build(BuildContext context) {
    final brand = thing.attributes['brand']?.toString().trim() ?? '';
    final model = thing.attributes['model']?.toString().trim() ?? '';
    final confidence = thing.attributes['aiConfidence'];
    final value = thing.estimatedCurrentValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 92,
                height: 92,
                child: thing.photoUrls.isEmpty
                    ? const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.inventory_2_outlined, size: 34),
                      )
                    : Image.network(
                        thing.photoUrls.first,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) {
                            return child;
                          }

                          return const ColoredBox(
                            color: Colors.black12,
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, error, _) {
                          debugPrint(
                            'Keepi thumbnail failed for '
                            '${thing.photoUrls.first}: $error',
                          );

                          return const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.broken_image_outlined),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 4),
                  Text(
                    [
                      _pretty(thing.categoryId),
                      if (thing.subcategoryId?.isNotEmpty == true)
                        thing.subcategoryId!,
                    ].join(' · '),
                  ),
                  if (brand.isNotEmpty || model.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [brand, model]
                          .where((value) => value.isNotEmpty)
                          .join(' '),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (thing.enabledActions.isEmpty ||
                          thing.enabledActions
                              .contains(ThingAction.personalUse))
                        _SmallChip(
                          icon: thing.visibility == ThingVisibility.private
                              ? Icons.visibility_off_outlined
                              : Icons.home_outlined,
                          label: thing.visibility == ThingVisibility.private
                              ? 'Personal'
                              : 'Personal use',
                        ),
                      for (final action in thing.enabledActions.where(
                        (action) => action != ThingAction.personalUse,
                      ))
                        _SmallChip(
                          icon: _actionIcon(action),
                          label: _actionLabel(action),
                        ),
                      if (value != null)
                        _SmallChip(
                          icon: Icons.sell_outlined,
                          label: '₪${value.round()}',
                        ),
                      if (confidence != null)
                        _SmallChip(
                          icon: Icons.auto_awesome,
                          label: 'AI $confidence%',
                        ),
                      if (thing.currentHolderName?.isNotEmpty == true)
                        _SmallChip(
                          icon: Icons.person_pin_circle_outlined,
                          label: 'With ${thing.currentHolderName}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Thing options',
              onSelected: (value) {
                if (value == 'lend') onMarkLent();
                if (value == 'returned') onMarkReturned();
              },
              itemBuilder: (context) => [
                if (thing.currentHolderName?.isNotEmpty != true)
                  const PopupMenuItem(
                    value: 'lend',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.person_add_alt_1_outlined),
                      title: Text('Mark as lent'),
                    ),
                  ),
                if (thing.currentHolderName?.isNotEmpty == true)
                  const PopupMenuItem(
                    value: 'returned',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.assignment_return_outlined),
                      title: Text('Mark as returned'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _actionLabel(ThingAction action) {
    switch (action) {
      case ThingAction.personalUse:
        return 'Personal use';
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

  static IconData _actionIcon(ThingAction action) {
    switch (action) {
      case ThingAction.personalUse:
        return Icons.home_outlined;
      case ThingAction.sell:
        return Icons.sell_outlined;
      case ThingAction.rent:
        return Icons.payments_outlined;
      case ThingAction.borrow:
        return Icons.handshake_outlined;
      case ThingAction.give:
        return Icons.volunteer_activism_outlined;
      case ThingAction.exchange:
        return Icons.swap_horiz;
    }
  }

  static String _pretty(String value) {
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
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
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photograph your first Thing and let Keepi identify it.',
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
