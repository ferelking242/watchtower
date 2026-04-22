import 'package:flutter/material.dart';
import 'package:watchtower/models/manga.dart';

/// Marketplace placeholder — surfaces user-published community extensions.
/// Backend wiring is pending; this screen explains the upcoming feature.
class MarketplaceScreen extends StatelessWidget {
  final ItemType itemType;
  const MarketplaceScreen({super.key, required this.itemType});

  String get _typeLabel {
    switch (itemType) {
      case ItemType.anime:
        return 'Watch';
      case ItemType.manga:
        return 'Manga';
      case ItemType.novel:
        return 'Novel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [cs.primary.withValues(alpha: 0.85), cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '$_typeLabel Marketplace',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Découvrez et publiez des extensions communautaires.\n'
              'Bientôt — chaque utilisateur pourra créer une extension '
              'et la publier ici en un tap depuis l\'écran de création.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 22),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Coming soon',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
