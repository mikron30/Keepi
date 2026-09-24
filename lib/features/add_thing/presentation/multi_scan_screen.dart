import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../inventory/data/thing_repository.dart';
import '../data/multi_item_scan_service.dart';
import '../domain/scanned_thing_candidate.dart';
import '../domain/thing_recognition.dart';

class MultiScanScreen extends StatefulWidget {
  const MultiScanScreen({super.key});

  @override
  State<MultiScanScreen> createState() => _MultiScanScreenState();
}

class _MultiScanScreenState extends State<MultiScanScreen> {
  final _picker = ImagePicker();
  final _repository = ThingRepository();
  final _scanService = const MultiItemScanService();

  Uint8List? _imageBytes;
  String _mimeType = 'image/jpeg';
  String? _imageName;
  List<_DetectedThingDraft> _drafts = [];
  MultiScanProgress? _scanProgress;

  bool _busy = false;
  String? _status;
  Timer? _ticker;
  DateTime? _scanStartedAt;
  int _liveElapsedSeconds = 0;
  double? _saveProgress;
  int _saveCompleted = 0;
  int _saveTotal = 0;

  @override
  void dispose() {
    _ticker?.cancel();
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
      _scanProgress = null;
    });

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 3000,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      for (final draft in _drafts) {
        draft.dispose();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _drafts = [];
        _imageBytes = bytes;
        _imageName = image.name;
        _mimeType = image.mimeType ?? _guessMimeType(image.name);
        _status = 'Preparing image...';
        _scanStartedAt = DateTime.now();
        _liveElapsedSeconds = 0;
      });

      _startTicker();

      MultiScanProgress? finalProgress;

      await for (final progress in _scanService.scan(imageBytes: bytes)) {
        finalProgress = progress;

        if (!mounted) {
          return;
        }

        setState(() {
          _scanProgress = progress;
          _status = progress.message;
        });
      }

      if (!mounted || finalProgress == null) {
        return;
      }

      if (finalProgress.stage == MultiScanStage.failed) {
        _showMessage(
          _friendlyScanError(
            finalProgress.errorMessage ?? 'Unknown scan error',
          ),
        );
        return;
      }

      final candidates = finalProgress.items;

      setState(() {
        _drafts = candidates.map(_DetectedThingDraft.new).toList();
        _status = 'Identified ${candidates.length} Things.';
      });

      if (_drafts.isEmpty) {
        _showMessage(
          'Keepi could not confidently identify any of the detected products. '
          'Try a closer, sharper photo.',
        );
      } else if (finalProgress.failedItems > 0) {
        _showMessage(
          'Identified ${candidates.length} of '
          '${finalProgress.totalDetected} detected products.',
        );
      }
    } catch (error) {
      _showMessage(_friendlyScanError(error));
    } finally {
      _stopTicker();

      if (mounted) {
        setState(() {
          _busy = false;
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
        .map((draft) => draft.toCandidate())
        .where((candidate) => candidate.recognition.name.trim().isNotEmpty)
        .toList();

    if (selected.isEmpty) {
      _showMessage('Select at least one item to add.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Preparing ${selected.length} Things for upload...';
      _saveCompleted = 0;
      _saveTotal = selected.length + 1;
      _saveProgress = 0;
    });

    try {
      final count = await _repository.createThingsFromMultiScan(
        sourceImageBytes: bytes,
        sourceMimeType: _mimeType,
        candidates: selected,
        onProgress: (completed, total, stage) {
          if (!mounted) return;
          setState(() {
            _saveCompleted = completed;
            _saveTotal = total;
            _saveProgress = total <= 0 ? null : completed / total;
            _status = stage;
          });
        },
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
          _saveProgress = null;
          _saveCompleted = 0;
          _saveTotal = 0;
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

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _scanStartedAt;
      if (!mounted || startedAt == null || !_busy) {
        return;
      }

      setState(() {
        _liveElapsedSeconds =
            DateTime.now().difference(startedAt).inSeconds;
      });
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  String _friendlyScanError(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('failed to fetch') ||
        lower.contains('clientexception')) {
      return 'Keepi could not complete the AI scan because the AI connection '
          'failed. Your photo was not split into arbitrary areas; Keepi first '
          'asks AI to locate each product, then crops and identifies them one '
          'by one. Check the connection and try again.';
    }

    return 'Multi-item scan failed: $message';
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '—';
    }

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
            'Keepi first uses AI to locate every separate product in the full '
            'photo. It then crops each product and identifies the crops one by '
            'one — ideal for books, shoes, tools and other collections.',
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
              label: const Text('Photograph collection'),
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
          ],
          if (_scanProgress != null) ...[
            const SizedBox(height: 20),
            _ScanProgressCard(
              progress: _scanProgress!,
              liveElapsed: Duration(seconds: _liveElapsedSeconds),
              formatDuration: _formatDuration,
            ),
          ] else if (_busy) ...[
            const SizedBox(height: 22),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              _status ?? 'Working...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (_saveProgress != null) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status ?? 'Saving Things...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _saveProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_saveCompleted/$_saveTotal uploads completed',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_drafts.length} identified · $selectedCount selected',
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            draft.candidate.cropBytes,
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                  _pretty(
                                    draft.candidate.recognition.categoryId,
                                  ),
                                  if (draft.candidate.recognition.subcategory
                                      .isNotEmpty)
                                    draft.candidate.recognition.subcategory,
                                  'AI ${draft.candidate.recognition.confidence}%',
                                  'Product ${draft.candidate.itemIndex}',
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

class _ScanProgressCard extends StatelessWidget {
  const _ScanProgressCard({
    required this.progress,
    required this.liveElapsed,
    required this.formatDuration,
  });

  final MultiScanProgress progress;
  final Duration liveElapsed;
  final String Function(Duration? duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final elapsed = liveElapsed > progress.elapsed
        ? liveElapsed
        : progress.elapsed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              progress.message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.stage == MultiScanStage.failed
                  ? null
                  : progress.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
            ),
            if (progress.currentCropBytes != null &&
                progress.stage == MultiScanStage.identifying) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      progress.currentCropBytes!,
                      width: 66,
                      height: 66,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progress.currentHint?.isNotEmpty == true
                          ? 'Current product: ${progress.currentHint}'
                          : 'Identifying current product...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProgressChip(
                  icon: Icons.center_focus_strong,
                  label: progress.totalDetected == 0
                      ? 'Finding products'
                      : '${progress.totalDetected} products found',
                ),
                if (progress.totalDetected > 0)
                  _ProgressChip(
                    icon: Icons.manage_search,
                    label: progress.currentItem == 0
                        ? 'Preparing crops'
                        : 'Product ${progress.currentItem}/${progress.totalDetected}',
                  ),
                _ProgressChip(
                  icon: Icons.inventory_2_outlined,
                  label: '${progress.identifiedCount} identified',
                ),
                _ProgressChip(
                  icon: Icons.timer_outlined,
                  label: '${formatDuration(elapsed)} elapsed',
                ),
                if (progress.estimatedRemaining != null &&
                    progress.stage == MultiScanStage.identifying)
                  _ProgressChip(
                    icon: Icons.hourglass_bottom,
                    label:
                        '~${formatDuration(progress.estimatedRemaining)} left',
                  ),
                if (progress.failedItems > 0)
                  _ProgressChip(
                    icon: Icons.warning_amber_rounded,
                    label: '${progress.failedItems} failed',
                  ),
              ],
            ),
            if (progress.logs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Live activity',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              ...progress.logs.reversed.take(4).map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $line',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
            ],
            if (progress.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                progress.errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DetectedThingDraft {
  _DetectedThingDraft(this.candidate)
      : nameController = TextEditingController(
          text: candidate.recognition.name,
        );

  final ScannedThingCandidate candidate;
  final TextEditingController nameController;
  bool selected = true;

  ScannedThingCandidate toCandidate() {
    final recognition = candidate.recognition;

    return candidate.copyWith(
      recognition: ThingRecognition(
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
      ),
    );
  }

  void dispose() {
    nameController.dispose();
  }
}
