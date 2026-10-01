import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Genres / Démographies / Collections » — Section 5 manga.
///
/// Genres, démographies, thèmes, collections / univers, tags, langues &
/// traductions, éditeurs et nouveautés par langue.
/// ─────────────────────────────────────────────────────────────────────────

/// Tuile de genre / thème avec compteur.
class MangaGenreEntry {
  final String title;

  ///(`1 248 mangas`).
  final String? countLabel;

  final IconData? icon;

  final Color? color;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const MangaGenreEntry({
    required this.title,
    this.countLabel,
    this.icon,
    this.color,
    this.thumbUrl,
    this.onTap,
  });
}

/// Tuile de collection / univers (poster + badge).
class MangaShowcaseEntry {
  final String title;

  final String? countLabel;

  /// Chip incrustée (`Shōnen`, `69`…).
  final String? badge;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const MangaShowcaseEntry({
    required this.title,
    this.countLabel,
    this.badge,
    this.thumbUrl,
    this.onTap,
  });
}

/// Tag coloré.
class MangaTagEntry {
  final String label;

  final Color? color;

  final IconData? icon;

  final VoidCallback? onTap;

  const MangaTagEntry({required this.label, this.color, this.icon, this.onTap});
}

/// Éditeur / maison de publication.
class MangaPublisherEntry {
  final String name;

  ///(`1 842 mangas`).
  final String? countLabel;

  /// Lettre / initiale affichée en logo.
  final String? initial;

  final String? logoUrl;

  final VoidCallback? onTap;

  const MangaPublisherEntry({
    required this.name,
    this.countLabel,
    this.initial,
    this.logoUrl,
    this.onTap,
  });
}

/// Équipe de traduction / scanlation.
class MangaTeamEntry {
  final String name;

  ///(`Official`, `Dédié fans`…).
  final String? meta;

  ///(`742 mangas`).
  final String? countLabel;

  final String? thumbUrl;

  const MangaTeamEntry({
    required this.name,
    this.meta,
    this.countLabel,
    this.thumbUrl,
  });
}

/// Ligne de statut de traduction.
class MangaStatusRow {
  final String label;

  ///(`42%`).
  final String percentLabel;

  /// Progression 0→1 de la barre.
  final double progress;

  final Color color;

  const MangaStatusRow({
    required this.label,
    required this.percentLabel,
    required this.progress,
    required this.color,
  });
}

/// Langue (nouveautés / disponibles).
class MangaLangEntry {
  final String name;

  ///(`1 248 mangas`, `142 chapitres`…).
  final String? countLabel;

  /// Initiale du drapeau / code.
  final String? code;

  const MangaLangEntry({required this.name, this.countLabel, this.code});
}

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

BoxDecoration _panelDecoration(Color accent, {double radius = 16}) {
  return BoxDecoration(
    color: const Color(0xFF15171D),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: accent.withValues(alpha: .18)),
  );
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Row(
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Broken.arrow_right_3, size: 12, color: Colors.white54),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ── 1. MangaGenresCard ──────────────────────────────────────────────────
/// Grille de genres avec compteurs.
class MangaGenresCard extends StatelessWidget {
  const MangaGenresCard({
    super.key,
    required this.items,
    this.width = 400,
    this.columns = 2,
    this.title = 'Genres',
    this.subtitle = 'Retrouve tes genres préférés.',
    this.onSeeAll,
  });

  final List<MangaGenreEntry> items;
  final double width;
  final int columns;
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.category_outlined,
            title: title,
            subtitle: subtitle,
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                SizedBox(
                  width: (width - 24 - (columns - 1) * 8) / columns,
                  child: _GenreTile(entry: item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.entry});

  final MangaGenreEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ContentImage(
                    url: entry.thumbUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entry.icon ?? Icons.star_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (entry.countLabel != null)
            Text(
              entry.countLabel!,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// ── 2. MangaDemographicsCard ────────────────────────────────────────────
/// Démographies (Shōnen, Shōjo, Seinen…).
class MangaDemographicsCard extends StatelessWidget {
  const MangaDemographicsCard({
    super.key,
    required this.items,
    this.width = 400,
    this.onSeeAll,
  });

  final List<MangaGenreEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.group_rounded,
            title: 'Démographies',
            subtitle: 'Les différentes catégories de public.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: (width - 24 - 8) / 2,
                  child: _DemographicRow(entry: items[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemographicRow extends StatelessWidget {
  const _DemographicRow({required this.entry});

  final MangaGenreEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ContentImage(url: entry.thumbUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.countLabel ?? '',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
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

/// ── 3. MangaThemesCard ──────────────────────────────────────────────────
/// Thèmes (École, Isekai, Reincarnation…).
class MangaThemesCard extends StatelessWidget {
  const MangaThemesCard({
    super.key,
    required this.items,
    this.width = 360,
    this.onSeeAll,
  });

  final List<MangaGenreEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.auto_awesome_outlined,
            title: 'Thèmes',
            subtitle: 'Les thèmes qui rendent chaque histoire unique.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: (width - 24 - 8) / 2,
                  child: _DemographicRow(entry: items[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 4. MangaUniverseShowcaseCard ────────────────────────────────────────
/// Collections / Univers incontournables.
class MangaUniverseShowcaseCard extends StatelessWidget {
  const MangaUniverseShowcaseCard({
    super.key,
    required this.items,
    this.width = 430,
    this.title = 'Collections / Univers',
    this.onSeeAll,
  });

  final List<MangaShowcaseEntry> items;
  final double width;
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.collections_outlined,
            title: title,
            subtitle: 'Plonge dans les sagas et univers incontournables.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _ShowcaseTile(entry: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseTile extends StatelessWidget {
  const _ShowcaseTile({required this.entry});

  final MangaShowcaseEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ContentImage(
                      url: entry.thumbUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, .7, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black45,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                ),
                if (entry.badge != null)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (entry.countLabel != null)
              Text(
                entry.countLabel!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ── 5. MangaTagsCard ────────────────────────────────────────────────────
/// Grille de tags colorés.
class MangaTagsCard extends StatelessWidget {
  const MangaTagsCard({
    super.key,
    required this.tags,
    this.width = 430,
    this.onSeeAll,
  });

  final List<MangaTagEntry> tags;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.local_offer_outlined,
            title: 'Tags',
            subtitle: 'Affinez vos recherches avec les tags.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final tag in tags)
                InkWell(
                  onTap: tag.onTap,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (tag.color ?? accent).withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: (tag.color ?? accent).withValues(alpha: .5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tag.icon != null) ...[
                          Icon(
                            tag.icon,
                            size: 10,
                            color: tag.color ?? accent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          tag.label,
                          style: TextStyle(
                            color: tag.color ?? accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 6. MangaLanguagesCard ───────────────────────────────────────────────
/// Langues / Traductions (3 colonnes).
class MangaLanguagesCard extends StatelessWidget {
  const MangaLanguagesCard({
    super.key,
    required this.languages,
    required this.teams,
    required this.statusRows,
    this.width = 430,
    this.onSeeLanguages,
    this.onSeeTeams,
    this.onSeePlatforms,
  });

  final List<MangaLangEntry> languages;
  final List<MangaTeamEntry> teams;
  final List<MangaStatusRow> statusRows;
  final double width;
  final VoidCallback? onSeeLanguages;
  final VoidCallback? onSeeTeams;
  final VoidCallback? onSeePlatforms;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.language_rounded,
            title: 'Langues / Traductions',
            subtitle:
                'Choisis ta langue ou découvre les traductions disponibles.',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LangColumn(
                  title: 'Langues disponibles',
                  onSeeAll: onSeeLanguages,
                  seeAllLabel: 'Voir toutes les langues',
                  rows: [
                    for (final l in languages)
                      (l.name, l.countLabel ?? '', null),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LangColumn(
                  title: 'Traductions & Scanlations',
                  onSeeAll: onSeeTeams,
                  seeAllLabel: 'Voir toutes les équipes',
                  rows: [
                    for (final t in teams)
                      (t.name, t.countLabel ?? '', t.meta),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatusColumn(rows: statusRows, onSee: onSeePlatforms),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LangColumn extends StatelessWidget {
  const _LangColumn({
    required this.title,
    required this.rows,
    required this.seeAllLabel,
    this.onSeeAll,
  });

  final String title;
  final List<(String, String, String?)> rows;
  final String seeAllLabel;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    rows[i].$1.characters.first,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSeeAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                seeAllLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({required this.rows, this.onSee});

  final List<MangaStatusRow> rows;
  final VoidCallback? onSee;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statut de traduction',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: rows[i].progress,
                          minHeight: 3.5,
                          backgroundColor:
                              Colors.white.withValues(alpha: .08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rows[i].color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rows[i].percentLabel,
                  style: TextStyle(
                    color: rows[i].color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Broken.tick_circle, size: 13, color: accent),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Manga officiel disponible sur les plateformes légales.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSee,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: .14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'Voir les plateformes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 7. MangaPublishersCard ──────────────────────────────────────────────
/// Éditeurs & Publications.
class MangaPublishersCard extends StatelessWidget {
  const MangaPublishersCard({
    super.key,
    required this.publishers,
    this.width = 360,
    this.onSeeAll,
  });

  final List<MangaPublisherEntry> publishers;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.business_rounded,
            title: 'Éditeurs & Publications',
            subtitle: 'Éditeurs, maisons d’édition et magazines.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in publishers)
                SizedBox(
                  width: (width - 24 - 16) / 3,
                  child: _PublisherTile(publisher: p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublisherTile extends StatelessWidget {
  const _PublisherTile({required this.publisher});

  final MangaPublisherEntry publisher;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: publisher.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: publisher.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: ContentImage(url: publisher.logoUrl),
                    )
                  : Text(
                      publisher.initial ?? publisher.name.characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            const SizedBox(height: 7),
            Text(
              publisher.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (publisher.countLabel != null)
              Text(
                publisher.countLabel!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ── 8. MangaLanguageNewsCard ────────────────────────────────────────────
/// Nouveautés par langue.
class MangaLanguageNewsCard extends StatelessWidget {
  const MangaLanguageNewsCard({
    super.key,
    required this.entries,
    this.width = 430,
    this.onSeeAll,
  });

  final List<MangaLangEntry> entries;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.language_rounded,
            title: 'Nouveautés par langue',
            subtitle: 'Les derniers ajouts dans les différentes langues.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .09),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            entries[i].code ?? entries[i].name.characters.first,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entries[i].name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              entries[i].countLabel ?? '',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
