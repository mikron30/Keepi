import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/images/keepi_icon.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keepi',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      Text(
                        'Your things. More value.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Messages',
                  onPressed: () => context.push('/messages'),
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xFF331710),
                          Color(0xFF111827),
                          Color(0xFF07111D),
                        ]
                      : const [
                          Color(0xFFFFE3D6),
                          Color(0xFFFFF5EF),
                          Color(0xFFFFFBF8),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Scan it.\nOrganize it.\nUse it. Share it.',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.02,
                              letterSpacing: -0.9,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/keepi_icon.png',
                            width: 112,
                            height: 112,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Turn the things you already own into value — keep, sell, '
                      'rent, lend, swap or give away.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/add'),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Add a new item'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Quick actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.22,
              children: [
                _HomeActionCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'My Things',
                  subtitle: 'Browse and manage your items',
                  onTap: () => context.go('/things'),
                ),
                _HomeActionCard(
                  icon: Icons.travel_explore_outlined,
                  title: 'Explore',
                  subtitle: 'Find things nearby',
                  onTap: () => context.go('/explore'),
                ),
                _HomeActionCard(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan many',
                  subtitle: 'Shelf, fridge, tools and more',
                  onTap: () => context.push('/scan'),
                ),
                _HomeActionCard(
                  icon: Icons.forum_outlined,
                  title: 'Messages',
                  subtitle: 'Chat with other users',
                  onTap: () => context.push('/messages'),
                ),
                _HomeActionCard(
                  icon: Icons.sell_outlined,
                  title: 'Sell & share',
                  subtitle: 'Turn unused things into value',
                  onTap: () => context.go('/things'),
                ),
                _HomeActionCard(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  subtitle: 'Locations, phone and settings',
                  onTap: () => context.go('/profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: scheme.primary, size: 25),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
