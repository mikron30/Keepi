import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/keepi_icon.png',
                    width: 54,
                    height: 54,
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
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                      ),
                      Text(
                        'Your things. More value.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, scheme.secondary, 0.28)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Everything you own.\nOne place.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.06,
                          letterSpacing: -0.8,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Photograph it, let AI organize it, then keep it, sell it, '
                    'rent it, lend it or share it.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.88),
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go('/add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF303A9F),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Add a Thing'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'What do you want to do?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.18,
              children: [
                _LandingAction(
                  icon: Icons.document_scanner_outlined,
                  title: 'Scan many',
                  subtitle: 'Shelf, fridge, tools and more',
                  color: scheme.secondary,
                  foreground: scheme.onSecondary,
                  onTap: () => context.push('/scan'),
                ),
                _LandingAction(
                  icon: Icons.inventory_2_outlined,
                  title: 'My Things',
                  subtitle: 'Browse your folders and items',
                  color: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                  onTap: () => context.go('/things'),
                ),
                _LandingAction(
                  icon: Icons.travel_explore_outlined,
                  title: 'Explore',
                  subtitle: 'Find Things nearby',
                  color: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                  onTap: () => context.go('/explore'),
                ),
                _LandingAction(
                  icon: Icons.chat_bubble_outline,
                  title: 'Messages',
                  subtitle: 'Talk with other Keepi users',
                  color: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurface,
                  onTap: () => context.push('/messages'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WideLandingButton(
              icon: Icons.search,
              title: 'Search nearby Things',
              subtitle: 'Buy, rent, borrow, exchange or find free items',
              onTap: () => context.go('/explore'),
            ),
            const SizedBox(height: 12),
            _WideLandingButton(
              icon: Icons.person_outline,
              title: 'Profile & locations',
              subtitle: 'Phone, home location, current location and settings',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingAction extends StatelessWidget {
  const _LandingAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 30),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.78),
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

class _WideLandingButton extends StatelessWidget {
  const _WideLandingButton({
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
