import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MyThingsScreen extends StatelessWidget {
  const MyThingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Things')),
      body: Center(
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
                'Add your first Thing. Keepi will progressively identify, categorize and value it automatically.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/add'),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Add a Thing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
