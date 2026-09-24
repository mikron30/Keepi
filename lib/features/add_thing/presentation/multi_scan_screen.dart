import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../inventory/data/thing_repository.dart';
import '../data/thing_ai_service.dart';
import '../domain/thing_recognition.dart';

class MultiScanScreen extends StatefulWidget {
  const MultiScanScreen({super.key});

  @override
  State<MultiScanScreen> createState() => _MultiScanScreenState();
}

class _MultiScanScreenState extends State<MultiScanScreen> {
  final _picker = ImagePicker();
  final _repository = ThingRepository();

  Uint8List? _imageBytes;
  String _mimeType = 'image/jpeg';
  String? _imageName;
  List<_DetectedThingDraft> _drafts = [];
  bool _busy = false;
  String? _status;
  Timer? _progressTimer;
  int _elapsedSeconds = 0;
  bool _scanningWithAi = false;

  @override
  void dispose() {
    _progressTimer?.cancel();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _status = source == ImageSource.camera
          ? 'Opening camera...'
          : 'Opening gallery...';
    });

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
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
        _status = 'Preparing image for AI...';
        _scanningWithAi = true;
        _elapsedSeconds = 0;
      });
      _startProgressTimer();

      final recognized = await ThingAiService.recognizeMultiple(
        imageBytes: bytes,
        mimeType: _mimeType,
      );

      if (!mounted) {
        return;
      }

      for (final draft in _drafts) {
        draft.dispose();
      }

      setState(() {
        _drafts = recognized.map(_DetectedThingDraft.new).toList();
        _status = 'Found ${recognized.length} Things.';
        _scanningWithAi = false;
      });
      _stopProgressTimer();

      if (_drafts.isEmpty) {
        _showMessage(
          'Keepi could not confidently identify separate items. '
          'Try a closer, sharper photo.',
        );
      }
    } catch (error) {
      _stopProgressTimer();
      if (mounted) {
        setState(() => _scanningWithAi = false);
      }
      _showMessage(_friendlyScanError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (!_scanningWithAi && _drafts.isEmpty) {
            _status = null;
          }
        });
      }
    }
  }

  Future<void> _saveSelected() async {
    final bytes = _imageBytes;
    if (bytes == null || _busy) {
      return;
    }

    final selected = _drafts
        .where((draft) => draft.selected)
        .map((draft) => draft.toRecognition())
        .where((item) => item.name.trim().isNotEmpty)
        .toList();

    if (selected.isEmpty) {
      _showMessage('Select at least one item to add.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Adding ${selected.length} Things to My Things...';
    });

    try {
      final count = await _repository.createThingsFromScan(
        imageBytes: bytes,
        mimeType: _mimeType,
        recognitions: selected,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Added $count Things.');
      context.go('/things');
    } catch (error) {
      _showMessage('Could not save scanned Things: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  void _removeDraft(int index) {
    final draft = _drafts[index];
    setState(() {
      _drafts.removeAt(index);
    });
    draft.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_scanningWithAi) return;
      setState(() {
        _elapsedSeconds++;
        _status = _progressStage(_elapsedSeconds);
      });
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  String _progressStage(int seconds) {
    if (seconds < 5) return 'Uploading image securely...';
    if (seconds < 15) return 'Looking for separate objects and book spines...';
    if (seconds < 30) return 'Reading names, titles and labels...';
    if (seconds < 50) return 'Building the inventory list...';
    return 'Still analyzing a detailed image — almost there...';
  }

  double _estimatedProgress() {
    if (!_scanningWithAi) return 1;
    // This is an honest time-based estimate; Gemini returns item count only
    // when the structured response is complete.
    final value = 0.08 + (_elapsedSeconds / 75) * 0.84;
    return value.clamp(0.08, 0.92);
  }

  String _progressDetail() {
    if (!_scanningWithAi) return '';
    final remaining = (60 - _elapsedSeconds).clamp(0, 60);
    if (_elapsedSeconds < 60) {
      return '${_elapsedSeconds}s elapsed · usually ~${remaining}s remaining';
    }
    return '${_elapsedSeconds}s elapsed · detailed scans can take longer';
  }

  String _friendlyScanError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('failed to fetch') ||
        message.contains('clientexception')) {
      return 'Keepi could not reach Firebase AI Logic. '
          'Check the Firebase AI Logic API permission for the web API key, '
          'App Check, and your internet connection, then try again.';
    }
    return 'Multi-item scan failed: $error';
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
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
    final selectedCount = _drafts.where((draft) => draft.selected).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan multiple Things')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
        children: [
          Text(
            'One photo, many Things',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Great for bookshelves, tool racks, cupboards, closets and rooms. '
            'Keepi creates a separate inventory item for each thing it can identify.',
          ),
          const SizedBox(height: 18),
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
              const SizedBox(height: 6),
              Text(
                _imageName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
          ],
          if (_drafts.isEmpty) ...[
            FilledButton.icon(
              onPressed:
                  _busy ? null : () => _pickAndScan(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Photograph shelf / room'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _pickAndScan(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose a photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_drafts.length} detected · $selectedCount selected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            for (final draft in _drafts) {
                              draft.selected = true;
                            }
                          });
                        },
                  child: const Text('Select all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_drafts.length, (index) {
              final draft = _drafts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: draft.selected,
                          onChanged: _busy
                              ? null
                              : (value) {
                                  setState(() {
                                    draft.selected = value ?? false;
                                  });
                                },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: draft.nameController,
                                enabled: !_busy,
                                decoration: const InputDecoration(
                                  labelText: 'Item name',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  _pretty(draft.recognition.categoryId),
                                  if (draft.recognition.subcategory.isNotEmpty)
                                    draft.recognition.subcategory,
                                  'AI ${draft.recognition.confidence}%',
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed:
                              _busy ? null : () => _removeDraft(index),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _saveSelected,
              icon: const Icon(Icons.library_add_outlined),
              label: Text('Add $selectedCount to My Things'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _pickAndScan(ImageSource.camera),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan another photo'),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 22),
            LinearProgressIndicator(
              value: _scanningWithAi ? _estimatedProgress() : null,
            ),
            const SizedBox(height: 10),
            Text(
              _status ?? 'Working...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_scanningWithAi) ...[
              const SizedBox(height: 4),
              Text(
                _progressDetail(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Detected item count appears when AI finishes this pass.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
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
}

class _DetectedThingDraft {
  _DetectedThingDraft(this.recognition)
      : nameController = TextEditingController(text: recognition.name);

  final ThingRecognition recognition;
  final TextEditingController nameController;
  bool selected = true;

  ThingRecognition toRecognition() {
    return ThingRecognition(
      name: nameController.text.trim(),
      categoryId: recognition.categoryId,
      subcategory: recognition.subcategory,
      brand: recognition.brand,
      model: recognition.model,
      condition: recognition.condition,
      description: recognition.description,
      estimatedNewPriceIls: recognition.estimatedNewPriceIls,
      estimatedCurrentValueIls: recognition.estimatedCurrentValueIls,
      confidence: recognition.confidence,
      searchKeywords: recognition.searchKeywords,
    );
  }

  void dispose() {
    nameController.dispose();
  }
}
