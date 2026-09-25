import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../inventory/data/thing_repository.dart';
import '../data/background_scan_repository.dart';
import '../domain/background_scan_item.dart';

class MultiScanScreen extends StatefulWidget {
  const MultiScanScreen({super.key});

  @override
  State<MultiScanScreen> createState() => _MultiScanScreenState();
}

class _MultiScanScreenState extends State<MultiScanScreen> {
  final _picker = ImagePicker();
  final _scanRepository = BackgroundScanRepository();
  final _thingRepository = ThingRepository();

  StreamSubscription<Map<String, dynamic>?>? _jobSubscription;

  Uint8List? _imageBytes;
  String? _imageName;
  String? _sourceUrl;
  String? _jobId;
  Map<String, dynamic>? _job;
  List<_BackgroundThingDraft> _drafts = [];

  bool _uploading = false;
  bool _saving = false;
  double _uploadProgress = 0;
  String? _loadedItemsForJob;

  @override
  void initState() {
    super.initState();
    unawaited(_resumeLatestJob());
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _resumeLatestJob() async {
    try {
      final latest = await _scanRepository.findLatestUnreviewedJob();
      if (!mounted || latest == null) {
        return;
      }

      final jobId = latest['id']?.toString();
      if (jobId == null || jobId.isEmpty) {
        return;
      }

      _attachJob(jobId, initialJob: latest);
    } catch (_) {
      // A new scan can still be started if there is nothing to resume.
    }
  }

  Future<void> _pickAndStart(ImageSource source) async {
    if (_uploading || _saving || _jobIsActive) {
      return;
    }

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 3000,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    final mimeType = image.mimeType ?? _guessMimeType(image.name);

    for (final draft in _drafts) {
      draft.dispose();
    }

    setState(() {
      _imageBytes = bytes;
      _imageName = image.name;
      _sourceUrl = null;
      _jobId = null;
      _job = null;
      _drafts = [];
      _loadedItemsForJob = null;
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final result = await _scanRepository.startScan(
        imageBytes: bytes,
        mimeType: mimeType,
        fileName: image.name,
        onUploadProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sourceUrl = result.sourceUrl;
        _uploading = false;
        _uploadProgress = 1;
      });

      _attachJob(result.jobId);
    } catch (error) {
      if (mounted) {
        setState(() => _uploading = false);
        _showMessage('Could not start background scan: $error');
      }
    }
  }

  void _attachJob(
    String jobId, {
    Map<String, dynamic>? initialJob,
  }) {
    unawaited(_jobSubscription?.cancel());

    setState(() {
      _jobId = jobId;
      if (initialJob != null) {
        _job = initialJob;
        _sourceUrl = initialJob['sourceUrl']?.toString();
      }
    });

    _jobSubscription = _scanRepository.watchJob(jobId).listen(
      (job) {
        if (!mounted || job == null) {
          return;
        }

        setState(() {
          _job = job;
          _sourceUrl = job['sourceUrl']?.toString() ?? _sourceUrl;
        });

        if (job['status'] == 'completed') {
          unawaited(_loadCompletedItems(jobId));
        }
      },
      onError: (Object error) {
        if (mounted) {
          _showMessage('Could not read background scan progress: $error');
        }
      },
    );

    if (initialJob?['status'] == 'completed') {
      unawaited(_loadCompletedItems(jobId));
    }
  }

  Future<void> _loadCompletedItems(String jobId) async {
    if (_loadedItemsForJob == jobId) {
      return;
    }

    _loadedItemsForJob = jobId;

    try {
      final items = await _scanRepository.loadItems(jobId);

      if (!mounted || _jobId != jobId) {
        return;
      }

      for (final draft in _drafts) {
        draft.dispose();
      }

      setState(() {
        _drafts = items.map(_BackgroundThingDraft.new).toList();
      });
    } catch (error) {
      _loadedItemsForJob = null;
      if (mounted) {
        _showMessage('Could not load scan results: $error');
      }
    }
  }

  Future<void> _saveSelected() async {
    final jobId = _jobId;
    if (jobId == null || _saving) {
      return;
    }

    final selectedDrafts =
        _drafts.where((draft) => draft.selected).toList();

    if (selectedDrafts.isEmpty) {
      _showMessage('Select at least one Thing to add.');
      return;
    }

    setState(() => _saving = true);

    try {
      final count = await _thingRepository.createThingsFromBackgroundScan(
        scanJobId: jobId,
        items: selectedDrafts.map((draft) => draft.item).toList(),
        editedNames: {
          for (final draft in selectedDrafts)
            draft.item.id: draft.nameController.text.trim(),
        },
      );

      await _scanRepository.markReviewed(jobId);

      if (!mounted) {
        return;
      }

      _showMessage('Added $count Things.');
      context.go('/things');
    } catch (error) {
      if (mounted) {
        _showMessage('Could not save scanned Things: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool get _jobIsActive {
    final status = _job?['status']?.toString();
    return const {
      'queued',
      'preparing',
      'locating',
      'identifying',
      'retrying',
      'saving_results',
    }.contains(status);
  }

  bool get _jobCompleted => _job?['status'] == 'completed';

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
    final selectedCount =
        _drafts.where((draft) => draft.selected).length;

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
            'Keepi uploads the collection photo once, then the Keepi backend '
            'locates individual products, crops them, and identifies several '
            'in parallel. The scan keeps running even if you leave the app.',
          ),
          const SizedBox(height: 18),
          if (_imageBytes != null || _sourceUrl?.isNotEmpty == true) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        _sourceUrl!,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy:
                            WebHtmlElementStrategy.fallback,
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
          if (_uploading) ...[
            _UploadCard(progress: _uploadProgress),
            const SizedBox(height: 16),
          ],
          if (_job != null) ...[
            _BackgroundProgressCard(job: _job!),
            const SizedBox(height: 16),
          ],
          if (_jobIsActive)
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_done_outlined),
                title: Text('Background scan is running'),
                subtitle: Text(
                  'The photo is already on Keepi servers. You can leave this '
                  'screen or close the app; processing will continue.',
                ),
              ),
            ),
          if (!_jobIsActive && !_uploading && !_jobCompleted) ...[
            FilledButton.icon(
              onPressed:
                  _saving ? null : () => _pickAndStart(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Photograph collection'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  _saving ? null : () => _pickAndStart(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose a photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
          if (_job?['status'] == 'failed') ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  (_job?['error'] ?? 'Background scan failed.').toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed:
                  _saving ? null : () => _pickAndStart(ImageSource.gallery),
              icon: const Icon(Icons.refresh),
              label: const Text('Try another photo'),
            ),
          ],
          if (_jobCompleted && _drafts.isEmpty) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Loading identified products...')),
          ],
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_drafts.length} identified · '
                    '$selectedCount selected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: _saving
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
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    draft.selected = value ?? false;
                                  });
                                },
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 62,
                            height: 62,
                            child: draft.item.cropUrl.isEmpty
                                ? const ColoredBox(
                                    color: Colors.black12,
                                    child: Icon(Icons.inventory_2_outlined),
                                  )
                                : Image.network(
                                    draft.item.cropUrl,
                                    fit: BoxFit.cover,
                                    webHtmlElementStrategy:
                                        WebHtmlElementStrategy.fallback,
                                    errorBuilder: (_, _, _) =>
                                        const ColoredBox(
                                      color: Colors.black12,
                                      child:
                                          Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: draft.nameController,
                                enabled: !_saving,
                                decoration: const InputDecoration(
                                  labelText: 'Item name',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  _pretty(draft.item.categoryId),
                                  if (draft.item.subcategory.isNotEmpty)
                                    draft.item.subcategory,
                                  'AI ${draft.item.confidence}%',
                                  'Product ${draft.item.index}',
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    draft.selected = false;
                                  });
                                },
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
              onPressed: _saving ? null : _saveSelected,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.library_add_outlined),
              label: Text(
                _saving
                    ? 'Saving to My Things...'
                    : 'Add $selectedCount to My Things',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
              ),
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

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uploading photo · $percent%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep this screen open only until the upload finishes. '
              'After that, the scan runs on Keepi servers.',
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundProgressCard extends StatelessWidget {
  const _BackgroundProgressCard({required this.job});

  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final progress = _readDouble(job['progress']).clamp(0.0, 1.0);
    final total = _readInt(job['totalDetected']);
    final processed = _readInt(job['processedCount']);
    final identified = _readInt(job['identifiedCount']);
    final failed = _readInt(job['failedItems']);
    final status = (job['status'] ?? '').toString();
    final message = (job['message'] ?? 'Working...').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: status == 'failed' ? null : progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProgressChip(
                  icon: Icons.center_focus_strong,
                  label: total == 0
                      ? 'Finding products'
                      : '$total products found',
                ),
                if (total > 0)
                  _ProgressChip(
                    icon: Icons.manage_search,
                    label: '$processed/$total processed',
                  ),
                _ProgressChip(
                  icon: Icons.inventory_2_outlined,
                  label: '$identified identified',
                ),
                if (failed > 0)
                  _ProgressChip(
                    icon: Icons.refresh,
                    label: status == 'retrying'
                        ? 'Retrying $failed'
                        : '$failed failed',
                  ),
                _ProgressChip(
                  icon: Icons.percent,
                  label: '${(progress * 100).round()}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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

class _BackgroundThingDraft {
  _BackgroundThingDraft(this.item)
      : nameController = TextEditingController(text: item.name);

  final BackgroundScanItem item;
  final TextEditingController nameController;
  bool selected = true;

  void dispose() {
    nameController.dispose();
  }
}
