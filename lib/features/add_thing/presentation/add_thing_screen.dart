import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddThingScreen extends StatefulWidget {
  const AddThingScreen({super.key});

  @override
  State<AddThingScreen> createState() => _AddThingScreenState();
}

class _AddThingScreenState extends State<AddThingScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _busy = false;

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _busy = true);

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
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _continue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Next: AI recognition, category and Firebase save.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a Thing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Show Keepi what you have',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a photo or choose one from your gallery. The same flow will later identify, categorize and value the Thing automatically.',
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
            const SizedBox(height: 8),
            if (_imageName != null)
              Text(
                _imageName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
          ],
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
          const _ActionCard(
            icon: Icons.view_in_ar_outlined,
            title: 'Scan a room',
            subtitle: 'Coming soon — detect multiple Things at once',
            onTap: null,
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_imageBytes != null && !_busy) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _continue,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Recognize this Thing'),
            ),
          ],
        ],
      ),
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
