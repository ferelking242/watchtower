import 'package:flutter/material.dart';
import 'package:watchtower/modules/plugin/nfile/core/icon_fonts/broken_icons.dart';

/// Nouvelle page « Chapter detail » ouverte depuis l'onglet du même nom
/// sur la page de détail d'un manga.
///
/// La page est encore en construction : on affiche un état propre et clair
/// plutôt qu'un écran vide, en attendant le vrai contenu (résumé du chapitre,
/// informations de scan, etc.).
class ChapterDetailScreen extends StatelessWidget {
  final String? title;

  const ChapterDetailScreen({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heading = (title == null || title!.trim().isEmpty)
        ? 'Chapter detail'
        : title!.trim();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Broken.arrow_left_2, size: 26),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          heading,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.10),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.28),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Broken.document_text,
                  size: 42,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'En cours de construction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'La page de détail des chapitres arrive bientôt.\n'
                'Vous y retrouverez le résumé, les informations de scan et '
                'tous les détails de chaque chapitre.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Broken.timer, size: 15, color: scheme.primary),
                    const SizedBox(width: 7),
                    Text(
                      'Disponible dans une prochaine mise à jour',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Broken.arrow_left_2, size: 18),
                label: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
