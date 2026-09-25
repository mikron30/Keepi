import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/thing_repository.dart';
import '../domain/thing.dart';

class EditThingScreen extends StatefulWidget {
  const EditThingScreen({
    required this.thingId,
    super.key,
  });

  final String thingId;

  @override
  State<EditThingScreen> createState() => _EditThingScreenState();
}

class _EditThingScreenState extends State<EditThingScreen> {
  final _repository = ThingRepository();

  final _nameController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _newPriceController = TextEditingController();
  final _currentValueController = TextEditingController();
  final _expiryController = TextEditingController();
  final _locationController = TextEditingController();
  final _customCategoryController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String _category = 'other';
  ThingCondition _condition = ThingCondition.unknown;
  Set<ThingAction> _enabledActions = {ThingAction.personalUse};

  static const _customCategoryValue = '__custom__';

  static const _categories = [
    'home',
    'vehicles',
    'tools',
    'sports',
    'garden',
    'electronics',
    'food',
    'drinks',
    'books',
    'clothing',
    'baby',
    'camping',
    'real_estate',
    'personal_care',
    'other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _subcategoryController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _newPriceController.dispose();
    _currentValueController.dispose();
    _expiryController.dispose();
    _locationController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _initializeFromThing(Thing thing) {
    if (_initialized) return;

    _initialized = true;
    _nameController.text = thing.name;
    _subcategoryController.text = thing.subcategoryId ?? '';
    _brandController.text = thing.attributes['brand']?.toString() ?? '';
    _modelController.text = thing.attributes['model']?.toString() ?? '';
    _descriptionController.text = thing.description ?? '';
    _quantityController.text = thing.quantity.toString();
    _newPriceController.text =
        thing.estimatedNewPrice?.round().toString() ?? '';
    _currentValueController.text =
        thing.estimatedCurrentValue?.round().toString() ?? '';
    _expiryController.text = thing.expiryDate == null
        ? ''
        : _formatDate(thing.expiryDate!);
    _locationController.text = thing.locationLabel ?? '';
    if (_categories.contains(thing.categoryId)) {
      _category = thing.categoryId;
    } else {
      _category = _customCategoryValue;
      _customCategoryController.text = _pretty(thing.categoryId);
    }
    _condition = thing.condition;
    _enabledActions = thing.enabledActions.isEmpty
        ? {ThingAction.personalUse}
        : {...thing.enabledActions};
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_expiryController.text.trim());

    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 15),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _expiryController.text = _formatDate(selected);
    });
  }

  void _toggleAction(ThingAction action, bool selected) {
    setState(() {
      if (selected) {
        _enabledActions.add(action);
      } else {
        _enabledActions.remove(action);
      }

      if (_enabledActions.isEmpty) {
        _enabledActions.add(ThingAction.personalUse);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final categoryId = _category == _customCategoryValue
        ? _customCategoryId(_customCategoryController.text)
        : _category;

    if (categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name for the new category.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _repository.updateThingDetails(
        thingId: widget.thingId,
        name: _nameController.text,
        categoryId: categoryId,
        subcategory: _subcategoryController.text,
        brand: _brandController.text,
        model: _modelController.text,
        condition: _condition,
        description: _descriptionController.text,
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        estimatedNewPrice: _parsePrice(_newPriceController.text),
        estimatedCurrentValue: _parsePrice(_currentValueController.text),
        expiryDate: DateTime.tryParse(_expiryController.text.trim()),
        locationLabel: _locationController.text,
        enabledActions: _enabledActions,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thing updated.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update Thing: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  double? _parsePrice(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  String _customCategoryId(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\\/]+'), ' ')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _pretty(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _conditionLabel(ThingCondition condition) {
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

  String _actionLabel(ThingAction action) {
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
        return 'Give away';
      case ThingAction.exchange:
        return 'Exchange';
    }
  }

  IconData _actionIcon(ThingAction action) {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Thing?>(
      stream: _repository.watchThing(widget.thingId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_initialized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Thing')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final thing = snapshot.data;
        if (thing == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Thing')),
            body: const Center(child: Text('Thing not found.')),
          );
        }

        _initializeFromThing(thing);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Thing'),
            actions: [
              TextButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: [
                  ..._categories.map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_pretty(value)),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _customCategoryValue,
                    child: Text('+ Create new category'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              if (_category == _customCategoryValue) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customCategoryController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'New category name',
                    hintText: 'For example: Musical instruments',
                    prefixIcon: Icon(Icons.create_new_folder_outlined),
                    helperText:
                        'Keepi will create a new folder with this category.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _subcategoryController,
                decoration: const InputDecoration(
                  labelText: 'Type / subcategory',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ThingCondition>(
                initialValue: _condition,
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: ThingCondition.values
                    .map(
                      (condition) => DropdownMenuItem(
                        value: condition,
                        child: Text(_conditionLabel(condition)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _condition = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'New price',
                        prefixText: '₪ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _currentValueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current value / price',
                        prefixText: '₪ ',
                      ),
                    ),
                  ),
                ],
              ),
              if (_category == 'food' || _category == 'drinks') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _expiryController,
                  readOnly: true,
                  onTap: _saving ? null : _pickExpiryDate,
                  decoration: InputDecoration(
                    labelText: 'Expiry / best-before date',
                    hintText: 'Unknown',
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_expiryController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear expiry date',
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(_expiryController.clear);
                                  },
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Choose date',
                          onPressed: _saving ? null : _pickExpiryDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'Use / availability',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose one or more. Any marketplace option makes the Thing visible in Explore.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in ThingAction.values)
                    FilterChip(
                      selected: _enabledActions.contains(action),
                      avatar: Icon(_actionIcon(action), size: 18),
                      label: Text(_actionLabel(action)),
                      onSelected: _saving
                          ? null
                          : (selected) =>
                              _toggleAction(action, selected),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save changes'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
), '')
        .toLowerCase();
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _pretty(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _conditionLabel(ThingCondition condition) {
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

  String _actionLabel(ThingAction action) {
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
        return 'Give away';
      case ThingAction.exchange:
        return 'Exchange';
    }
  }

  IconData _actionIcon(ThingAction action) {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Thing?>(
      stream: _repository.watchThing(widget.thingId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_initialized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Thing')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final thing = snapshot.data;
        if (thing == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Thing')),
            body: const Center(child: Text('Thing not found.')),
          );
        }

        _initializeFromThing(thing);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Thing'),
            actions: [
              TextButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: _categories
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_pretty(value)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _category = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subcategoryController,
                decoration: const InputDecoration(
                  labelText: 'Type / subcategory',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ThingCondition>(
                initialValue: _condition,
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: ThingCondition.values
                    .map(
                      (condition) => DropdownMenuItem(
                        value: condition,
                        child: Text(_conditionLabel(condition)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _condition = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'New price',
                        prefixText: '₪ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _currentValueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current value / price',
                        prefixText: '₪ ',
                      ),
                    ),
                  ),
                ],
              ),
              if (_category == 'food' || _category == 'drinks') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _expiryController,
                  readOnly: true,
                  onTap: _saving ? null : _pickExpiryDate,
                  decoration: InputDecoration(
                    labelText: 'Expiry / best-before date',
                    hintText: 'Unknown',
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_expiryController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear expiry date',
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(_expiryController.clear);
                                  },
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Choose date',
                          onPressed: _saving ? null : _pickExpiryDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'Use / availability',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose one or more. Any marketplace option makes the Thing visible in Explore.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in ThingAction.values)
                    FilterChip(
                      selected: _enabledActions.contains(action),
                      avatar: Icon(_actionIcon(action), size: 18),
                      label: Text(_actionLabel(action)),
                      onSelected: _saving
                          ? null
                          : (selected) =>
                              _toggleAction(action, selected),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save changes'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
