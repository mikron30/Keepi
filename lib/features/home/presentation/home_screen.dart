import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/images/keepi_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Keepi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 28),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.push('/messages'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'What do you need?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              onTap: () => context.go('/explore'),
              decoration: const InputDecoration(
                hintText: 'Search for anything nearby...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.go('/add'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text(
                'Add a Thing',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'My Things',
              onTap: () => context.go('/things'),
            ),
            const _InfoCard(
              icon: Icons.inventory_2_outlined,
              title: 'Your inventory starts here',
              subtitle: 'Photograph anything you own and Keepi will build your catalog.',
            ),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Near You'),
            const _InfoCard(
              icon: Icons.location_on_outlined,
              title: 'Nearby Things',
              subtitle: 'Local rent, borrow, buy and give-away listings will appear here.',
            ),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'Expiring Soon'),
            const _InfoCard(
              icon: Icons.schedule_outlined,
              title: 'Nothing expiring yet',
              subtitle: 'Food, opened wine and other time-sensitive Things will appear here.',
            ),
            const SizedBox(height: 22),
            const _SectionHeader(title: 'People Need Nearby'),
            const _InfoCard(
              icon: Icons.handshake_outlined,
              title: 'Need requests',
              subtitle: 'Requests from people nearby will be matched with Things you own.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.onTap,
  });

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
