import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../inventory/data/thing_repository.dart';
import '../../inventory/domain/thing.dart';
import '../data/thing_ai_service.dart';
import '../domain/thing_recognition.dart';

class AddThingScreen extends StatefulWidget {
  const AddThingScreen({super.key});

  @override
  State<AddThingScreen> createState() => _AddThingScreenState();
}

class _AddThingScreenState extends State<AddThingScreen> {
  static const _categories = <String>[
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

  static const _conditions = <String>[
    'new',
    'like_new',
    'good',
    'fair',
    'poor',
    'unknown',
  ];

  final ImagePicker _picker = ImagePicker();
  final ThingRepository _thingRepository = ThingRepository();

  final _nameController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _newPriceController = TextEditingController();
  final _usedPriceController = TextEditingController();
  final _descriptionController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;
  String _mimeType = 'image/jpeg';
  ThingRecognition? _recognition;
  String _category = 'other';
  String _condition = 'unknown';
  Set<ThingAction> _enabledActions = {ThingAction.personalUse};
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _nameController.dispose();
    _subcategoryController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _newPriceController.dispose();
    _usedPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _busy = true;
      _status = source == ImageSource.camera
          ? 'Opening camera...'
          : 'Opening gallery...';
    });

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = image.name;
        _mimeType = image.mimeType ?? _guessMimeType(image.name);
        _recognition = null;
        _status = null;
        _clearRecognitionFields();
      });
    } catch (error) {
      _showMessage('Could not open the image: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _recognize() async {
    final bytes = _imageBytes;
    if (bytes == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Keepi AI is identifying this Thing...';
    });

    try {
      final recognition = await ThingAiService.recognize(
        imageBytes: bytes,
        mimeType: _mimeType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recognition = recognition;
        _nameController.text = recognition.name;
        _subcategoryController.text = recognition.subcategory;
        _brandController.text = recognition.brand;
        _modelController.text = recognition.model;
        _newPriceController.text = recognition.estimatedNewPriceIls > 0
            ? recognition.estimatedNewPriceIls.toString()
            : '';
        _usedPriceController.text = recognition.estimatedCurrentValueIls > 0
            ? recognition.estimatedCurrentValueIls.toString()
            : '';
        _descriptionController.text = recognition.description;
        _category = _categories.contains(recognition.categoryId)
            ? recognition.categoryId
            : 'other';
        _condition = _conditions.contains(recognition.condition)
            ? recognition.condition
            : 'unknown';
        _status = null;
      });
    } catch (error) {
      _showMessage(_friendlyAiError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _saveThing() async {
    final bytes = _imageBytes;
    final recognition = _recognition;

    if (bytes == null || recognition == null || _busy) {
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Give this Thing a name before saving.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Uploading photo and saving your Thing...';
    });

    try {
      await _thingRepository.createThing(
        imageBytes: bytes,
        mimeType: _mimeType,
        recognition: recognition,
        name: name,
        categoryId: _category,
        subcategory: _subcategoryController.text,
        brand: _brandController.text,
        model: _modelController.text,
        condition: _condition,
        description: _descriptionController.text,
        estimatedNewPriceIls: _parsePrice(_newPriceController.text),
        estimatedCurrentValueIls: _parsePrice(_usedPriceController.text),
        enabledActions: _enabledActions,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Saved to My Things.');
      _reset();
      context.go('/things');
    } catch (error) {
      _showMessage(_friendlySaveError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _mimeType = 'image/jpeg';
      _recognition = null;
      _category = 'other';
      _condition = 'unknown';
      _enabledActions = {ThingAction.personalUse};
      _clearRecognitionFields();
    });
  }

  void _clearRecognitionFields() {
    _nameController.clear();
    _subcategoryController.clear();
    _brandController.clear();
    _modelController.clear();
    _newPriceController.clear();
    _usedPriceController.clear();
    _descriptionController.clear();
    _category = 'other';
    _condition = 'unknown';
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

  int _parsePrice(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _friendlyAiError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('not enabled') ||
        lower.contains('permission') ||
        lower.contains('403') ||
        lower.contains('firebase ai')) {
      return 'Keepi AI is not enabled for this Firebase project yet. '
          'Open Firebase Console > AI Logic, complete Get started, then try again.';
    }

    return 'AI recognition failed: $text';
  }

  String _friendlySaveError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('storage') ||
        lower.contains('bucket') ||
        lower.contains('object-not-found') ||
        lower.contains('upload timed out')) {
      return 'Photo upload could not finish. Open Firebase Console > Storage, '
          'make sure Storage is enabled for Keepi, then publish the latest rules.';
    }

    if (lower.contains('permission-denied') ||
        lower.contains('firestore save timed out')) {
      return 'Firebase blocked or could not finish the save. '
          'Deploy the latest Firestore and Storage rules.';
    }

    return 'Could not save this Thing: $text';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a Thing'),
        actions: [
          if (_imageBytes != null)
            IconButton(
              tooltip: 'Start over',
              onPressed: _busy ? null : _reset,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            _recognition == null
                ? 'Show Keepi what you have'
                : 'Check what Keepi found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _recognition == null
                ? 'Take one clear photo. Keepi will identify, categorize and estimate the value automatically.'
                : 'AI suggestions are editable. Confirm the details before saving to your private inventory.',
          ),
          const SizedBox(height: 24),
          if (_imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.memory(
                  _imageBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (_imageName != null) ...[
              const SizedBox(height: 8),
              Text(
                _imageName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
          ],
          if (_recognition == null) ...[
            _ActionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Take a photo',
              subtitle: 'Photograph one Thing',
              onTap: _busy ? null : () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              subtitle: 'Use a photo you already have',
              onTap: _busy ? null : () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.view_in_ar_outlined,
              title: 'Scan multiple Things',
              subtitle: 'Bookshelf, room, tools, cupboard and more',
              onTap: _busy ? null : () => context.push('/scan'),
            ),
            if (_imageBytes != null && !_busy) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _recognize,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Recognize this Thing'),
              ),
            ],
          ] else ...[
            _RecognitionEditor(
              recognition: _recognition!,
              nameController: _nameController,
              subcategoryController: _subcategoryController,
              brandController: _brandController,
              modelController: _modelController,
              newPriceController: _newPriceController,
              usedPriceController: _usedPriceController,
              descriptionController: _descriptionController,
              category: _category,
              condition: _condition,
              categories: _categories,
              conditions: _conditions,
              onCategoryChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
              onConditionChanged: (value) {
                if (value != null) setState(() => _condition = value);
              },
            ),
            const SizedBox(height: 18),
            Text(
              'What can others do with this Thing?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose one or more. Personal use stays private unless you also select a marketplace option.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ThingActionChip(
                  action: ThingAction.personalUse,
                  label: 'Personal use',
                  icon: Icons.home_outlined,
                  selected: _enabledActions.contains(ThingAction.personalUse),
                  onSelected: _toggleAction,
                ),
                _ThingActionChip(
                  action: ThingAction.sell,
                  label: 'Sell',
                  icon: Icons.sell_outlined,
                  selected: _enabledActions.contains(ThingAction.sell),
                  onSelected: _toggleAction,
                ),
                _ThingActionChip(
                  action: ThingAction.rent,
                  label: 'Rent',
                  icon: Icons.payments_outlined,
                  selected: _enabledActions.contains(ThingAction.rent),
                  onSelected: _toggleAction,
                ),
                _ThingActionChip(
                  action: ThingAction.borrow,
                  label: 'Lend',
                  icon: Icons.handshake_outlined,
                  selected: _enabledActions.contains(ThingAction.borrow),
                  onSelected: _toggleAction,
                ),
                _ThingActionChip(
                  action: ThingAction.give,
                  label: 'Give away',
                  icon: Icons.volunteer_activism_outlined,
                  selected: _enabledActions.contains(ThingAction.give),
                  onSelected: _toggleAction,
                ),
                _ThingActionChip(
                  action: ThingAction.exchange,
                  label: 'Exchange',
                  icon: Icons.swap_horiz,
                  selected: _enabledActions.contains(ThingAction.exchange),
                  onSelected: _toggleAction,
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _busy ? null : _saveThing,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text(
                'Save to My Things',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _busy ? null : _recognize,
              icon: const Icon(Icons.refresh),
              label: const Text('Run AI again'),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 24),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              _status ?? 'Working...',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecognitionEditor extends StatelessWidget {
  const _RecognitionEditor({
    required this.recognition,
    required this.nameController,
    required this.subcategoryController,
    required this.brandController,
    required this.modelController,
    required this.newPriceController,
    required this.usedPriceController,
    required this.descriptionController,
    required this.category,
    required this.condition,
    required this.categories,
    required this.conditions,
    required this.onCategoryChanged,
    required this.onConditionChanged,
  });

  final ThingRecognition recognition;
  final TextEditingController nameController;
  final TextEditingController subcategoryController;
  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController newPriceController;
  final TextEditingController usedPriceController;
  final TextEditingController descriptionController;
  final String category;
  final String condition;
  final List<String> categories;
  final List<String> conditions;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onConditionChanged;

  String _pretty(String value) {
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI confidence: ${recognition.confidence}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Chip(label: Text('AI estimate')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: categories
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_pretty(value)),
                ),
              )
              .toList(),
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: subcategoryController,
          decoration: const InputDecoration(
            labelText: 'Subcategory',
            prefixIcon: Icon(Icons.account_tree_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: brandController,
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: modelController,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: condition,
          decoration: const InputDecoration(
            labelText: 'Condition',
            prefixIcon: Icon(Icons.health_and_safety_outlined),
          ),
          items: conditions
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_pretty(value)),
                ),
              )
              .toList(),
          onChanged: onConditionChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newPriceController,
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
                controller: usedPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Used value',
                  prefixText: '₪ ',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Prices are AI estimates for now and can be corrected before saving.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(radius: 28, child: Icon(icon, size: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
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


class _ThingActionChip extends StatelessWidget {
  const _ThingActionChip({
    required this.action,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final ThingAction action;
  final String label;
  final IconData icon;
  final bool selected;
  final void Function(ThingAction action, bool selected) onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (value) => onSelected(action, value),
    );
  }
}
