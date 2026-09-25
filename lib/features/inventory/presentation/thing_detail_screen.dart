import 'package:flutter/material.dart';

import '../data/thing_repository.dart';
import '../domain/thing.dart';

class ThingDetailScreen extends StatefulWidget {
  const ThingDetailScreen({
    required this.thingId,
    super.key,
  });

  final String thingId;

  @override
  State<ThingDetailScreen> createState() => _ThingDetailScreenState();
}

class _ThingDetailScreenState extends State<ThingDetailScreen> {
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
                if (name.isNotEmpty) {
                  Navigator.pop(context, name);
                }
              },
              child: const Text('Mark as lent'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (borrowerName == null || borrowerName.isEmpty) {
      return;
    }

    try {
      await _repository.markThingLent(
        thingId: thing.id,
        borrowerName: borrowerName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${thing.name} is now with $borrowerName.'),
          ),
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
    return StreamBuilder<Thing?>(
      stream: _repository.watchThing(widget.thingId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thing')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this Thing: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thing')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final thing = snapshot.data;
        if (thing == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Thing')),
            body: const Center(child: Text('Thing not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(thing.name)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
            children: [
              _ProductImage(thing: thing),
              const SizedBox(height: 18),
              Text(
                thing.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (thing.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  thing.description!.trim(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 18),
              _InfoSection(
                children: [
                  _InfoRow(
                    icon: Icons.folder_outlined,
                    label: 'Category',
                    value: _categoryLabel(thing.categoryId),
                  ),
                  if (thing.subcategoryId?.trim().isNotEmpty == true)
                    _InfoRow(
                      icon: Icons.label_outline,
                      label: 'Type',
                      value: thing.subcategoryId!.trim(),
                    ),
                  if (_brandModel(thing).isNotEmpty)
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Brand / model',
                      value: _brandModel(thing),
                    ),
                  _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Condition',
                    value: _conditionLabel(thing.condition),
                  ),
                  if (thing.estimatedNewPrice != null)
                    _InfoRow(
                      icon: Icons.storefront_outlined,
                      label: 'Estimated new price',
                      value: '₪${thing.estimatedNewPrice!.round()}',
                    ),
                  if (thing.estimatedCurrentValue != null)
                    _InfoRow(
                      icon: Icons.sell_outlined,
                      label: 'Estimated current value',
                      value: '₪${thing.estimatedCurrentValue!.round()}',
                    ),
                  if (thing.categoryId == 'food' ||
                      thing.categoryId == 'drinks')
                    _InfoRow(
                      icon: Icons.event_outlined,
                      label: 'Expiry',
                      value: _expiryLabel(thing),
                    ),
                  if (thing.locationLabel?.trim().isNotEmpty == true)
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: thing.locationLabel!.trim(),
                    ),
                  if (thing.currentHolderName?.trim().isNotEmpty == true)
                    _InfoRow(
                      icon: Icons.person_pin_circle_outlined,
                      label: 'Current holder',
                      value: thing.currentHolderName!.trim(),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Use',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (thing.enabledActions.isEmpty ||
                      thing.enabledActions.contains(ThingAction.personalUse))
                    const Chip(
                      avatar: Icon(Icons.home_outlined, size: 18),
                      label: Text('Personal use'),
                    ),
                  for (final action in thing.enabledActions.where(
                    (action) => action != ThingAction.personalUse,
                  ))
                    Chip(
                      avatar: Icon(_actionIcon(action), size: 18),
                      label: Text(_actionLabel(action)),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              if (thing.currentHolderName?.trim().isNotEmpty == true)
                FilledButton.icon(
                  onPressed: () => _markReturned(thing),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Mark as returned'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _markLent(thing),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Mark as lent'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _brandModel(Thing thing) {
    final brand = thing.attributes['brand']?.toString().trim() ?? '';
    final model = thing.attributes['model']?.toString().trim() ?? '';
    return [brand, model].where((value) => value.isNotEmpty).join(' ');
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

  static String _conditionLabel(ThingCondition condition) {
    switch (condition) {
      case ThingCondition.newItem:
        return 'New';
      case ThingCondition.likeNew:
        return 'Like new';
      case ThingCondition.good:
        return 'Good';
      case ThingCondition.fair:
        return 'Fair';
      case ThingCondition.poor:
        return 'Poor';
      case ThingCondition.unknown:
        return 'Unknown';
    }
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

  static String _expiryLabel(Thing thing) {
    final expiry = thing.expiryDate;
    if (expiry == null) {
      return 'Unknown';
    }

    final date =
        '${expiry.year.toString().padLeft(4, '0')}-'
        '${expiry.month.toString().padLeft(2, '0')}-'
        '${expiry.day.toString().padLeft(2, '0')}';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final days = expiryDay.difference(today).inDays;

    if (days < 0) return 'Expired · $date';
    if (days == 0) return 'Expires today · $date';
    if (days <= 7) return 'In $days days · $date';
    return date;
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.thing});

  final Thing thing;

  @override
  Widget build(BuildContext context) {
    final imageUrl = thing.thumbnailUrl?.trim().isNotEmpty == true
        ? thing.thumbnailUrl!.trim()
        : (thing.photoUrls.isEmpty ? null : thing.photoUrls.first);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: imageUrl == null
            ? const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.inventory_2_outlined, size: 72),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image_outlined, size: 60),
                ),
              ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          value,
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
