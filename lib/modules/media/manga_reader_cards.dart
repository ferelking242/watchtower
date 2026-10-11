import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Lecture / Reader » — Section 6 manga (Watchtower).
///
/// Expérience de lecture : pages, modes, direction, réglages, progression,
/// navigation entre chapitres, accès rapides et historique.
/// ─────────────────────────────────────────────────────────────────────────

/// Page de manga (numéro + visuel).
class MangaReaderPage {
  final String label;
  final String? url;

  const MangaReaderPage({required this.label, this.url});
}

/// Entrée d'historique de lecture.
class MangaReaderHistoryEntry {
  final String title;

  ///(`Chapitre 1160`).
  final String? subtitle;

  ///(`82%`).
  final String? percentLabel;

  /// Progression 0→1.
  final double progress;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const MangaReaderHistoryEntry({
    required this.title,
    this.subtitle,
    this.percentLabel,
    required this.progress,
    this.thumbUrl,
    this.onTap,
  });
}

/// Ligne de chapitre (liste de lecture).
class MangaReaderChapterRow {
  final String title;

  ///(`il y a 2 h`).
  final String? timeAgo;

  final String? thumbUrl;

  /// Chapitre déjà lu.
  final bool read;

  /// Affiche un bouton « Lire ».
  final bool showReadButton;

  final VoidCallback? onTap;

  const MangaReaderChapterRow({
    required this.title,
    this.timeAgo,
    this.thumbUrl,
    this.read = false,
    this.showReadButton = false,
    this.onTap,
  });
}

/// Option de lecture (mode, direction…).
class MangaReadingOption {
  final String label;

  ///(`page par page`, `standard manga`…).
  final String? sublabel;

  final IconData icon;

  final bool selected;

  const MangaReadingOption({
    required this.label,
    this.sublabel,
    required this.icon,
    this.selected = false,
  });
}

/// Ligne de réglage du reader.
class MangaSettingRow {
  final String label;

  ///(`Normal`, `HD`, `100%`…).
  final String? value;

  final IconData icon;

  const MangaSettingRow({required this.label, this.value, required this.icon});
}

/// Action rapide du reader.
class MangaQuickAction {
  final String label;
  final IconData icon;

  const MangaQuickAction({required this.label, required this.icon});
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

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, this.subtitle, {this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PageArrow extends StatelessWidget {
  const _PageArrow({this.onTap, this.forward = true});

  final VoidCallback? onTap;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          forward ? Broken.arrow_right_3 : Icons.arrow_back_rounded,
          size: 13,
          color: accent,
        ),
      ),
    );
  }
}

/// ── 1. MangaReaderCard ──────────────────────────────────────────────────
/// Accès rapide à la lecture d'un manga.
class MangaReaderCard extends StatelessWidget {
  const MangaReaderCard({
    super.key,
    required this.title,
    this.author,
    this.statusLabel,
    this.chapterLabel,
    this.pageLabel,
    this.coverUrl,
    this.width = 300,
    this.onRead,
  });

  final String title;
  final String? author;
  final String? statusLabel;
  final String? chapterLabel;
  final String? pageLabel;
  final String? coverUrl;
  final double width;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            height: 122,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ContentImage(url: coverUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (author != null)
                  Text(
                    author!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                if (statusLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ED573).withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2ED573).withValues(alpha: .5),
                      ),
                    ),
                    child: Text(
                      statusLabel!,
                      style: const TextStyle(
                        color: Color(0xFF2ED573),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  chapterLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pageLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRead,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Broken.play, size: 12),
                        SizedBox(width: 5),
                        Text(
                          'Lire maintenant',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 2. MangaPageCard ────────────────────────────────────────────────────
/// Une page de manga en haute qualité.
class MangaPageCard extends StatelessWidget {
  const MangaPageCard({
    super.key,
    required this.pageUrl,
    this.pageLabel = '37',
    this.totalLabel = '184',
    this.width = 340,
    this.onPrev,
    this.onNext,
  });

  final String? pageUrl;
  final String pageLabel;
  final String totalLabel;
  final double width;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(8),
      decoration: _panelDecoration(accent, radius: 14),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ContentImage(url: pageUrl, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black87,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PageArrow(onTap: onPrev, forward: false),
                      const SizedBox(width: 10),
                      Text(
                        '$pageLabel / $totalLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PageArrow(onTap: onNext),
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

/// ── 3. MangaPagePreviewCard ─────────────────────────────────────────────
/// Aperçu des pages pour navigation rapide.
class MangaPagePreviewCard extends StatelessWidget {
  const MangaPagePreviewCard({
    super.key,
    required this.pages,
    this.width = 420,
    this.onPrev,
    this.onNext,
  });

  final List<MangaReaderPage> pages;
  final double width;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        children: [
          Row(
            children: [
              _PageArrow(onTap: onPrev, forward: false),
              const Spacer(),
              _PageArrow(onTap: onNext),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < pages.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: ContentImage(
                            url: pages[i].url,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        pages[i].label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 4. MangaPageStripCard ───────────────────────────────────────────────
/// Lecture en bandeau (strip).
class MangaPageStripCard extends StatelessWidget {
  const MangaPageStripCard({
    super.key,
    required this.pages,
    this.positionLabel = '3 / 12',
    this.width = 420,
    this.onPrev,
    this.onNext,
  });

  final List<MangaReaderPage> pages;
  final String positionLabel;
  final double width;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        children: [
          Row(
            children: [
              _PageArrow(onTap: onPrev, forward: false),
              const Spacer(),
              _PageArrow(onTap: onNext),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ContentImage(
                url: pages.isEmpty ? null : pages.first.url,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3 && i < pages.length; i++)
                Container(
                  width: 22,
                  height: 30,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: i == 0
                          ? accent
                          : Colors.white.withValues(alpha: .1),
                      width: i == 0 ? 1.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: ContentImage(url: pages[i].url, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                positionLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 5. MangaDoublePageCard ──────────────────────────────────────────────
/// Affichage double page.
class MangaDoublePageCard extends StatelessWidget {
  const MangaDoublePageCard({
    super.key,
    required this.leftUrl,
    required this.rightUrl,
    this.positionLabel = '12 - 13 / 40',
    this.width = 340,
    this.onPrev,
    this.onNext,
  });

  final String? leftUrl;
  final String? rightUrl;
  final String positionLabel;
  final double width;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(8),
      decoration: _panelDecoration(accent, radius: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ContentImage(url: leftUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ContentImage(url: rightUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageArrow(onTap: onPrev, forward: false),
              const SizedBox(width: 10),
              Text(
                positionLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              _PageArrow(onTap: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 6. MangaReadingModeCard ─────────────────────────────────────────────
/// Choix du mode de lecture.
class MangaReadingModeCard extends StatelessWidget {
  const MangaReadingModeCard({
    super.key,
    required this.options,
    this.width = 400,
    this.onSelected,
  });

  final List<MangaReadingOption> options;
  final double width;
  final ValueChanged<int>? onSelected;

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
          _CardTitle(
            'MangaReadingModeCard',
            'Choisis ton mode de lecture.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => onSelected?.call(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: options[i].selected
                            ? accent.withValues(alpha: .18)
                            : Colors.white.withValues(alpha: .04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: options[i].selected
                              ? accent
                              : Colors.white.withValues(alpha: .09),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            options[i].icon,
                            size: 20,
                            color: options[i].selected
                                ? accent
                                : Colors.white54,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            options[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: options[i].selected
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (options[i].sublabel != null)
                            Text(
                              options[i].sublabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 7. MangaReadingDirectionCard ────────────────────────────────────────
/// Direction de lecture.
class MangaReadingDirectionCard extends StatelessWidget {
  const MangaReadingDirectionCard({
    super.key,
    required this.options,
    this.width = 300,
    this.onSelected,
  });

  final List<MangaReadingOption> options;
  final double width;
  final ValueChanged<int>? onSelected;

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
          _CardTitle(
            'Direction de lecture',
            'Sens de lecture des planches.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => onSelected?.call(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: options[i].selected
                            ? accent.withValues(alpha: .18)
                            : Colors.white.withValues(alpha: .04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: options[i].selected
                              ? accent
                              : Colors.white.withValues(alpha: .09),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            options[i].icon,
                            size: 22,
                            color: options[i].selected
                                ? accent
                                : Colors.white54,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            options[i].label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: options[i].selected
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (options[i].sublabel != null)
                            Text(
                              options[i].sublabel!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 8. MangaReaderSettingsCard ──────────────────────────────────────────
/// Réglages de l'expérience de lecture.
class MangaReaderSettingsCard extends StatelessWidget {
  const MangaReaderSettingsCard({
    super.key,
    required this.rows,
    this.brightness = .6,
    this.nightMode = true,
    this.width = 340,
    this.onBrightnessChanged,
    this.onNightModeChanged,
  });

  final List<MangaSettingRow> rows;
  final double brightness;
  final bool nightMode;
  final double width;
  final ValueChanged<double>? onBrightnessChanged;
  final ValueChanged<bool>? onNightModeChanged;

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
          _CardTitle(
            'Réglages du reader',
            'Personnalise ton expérience de lecture.',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Row(
              children: [
                Icon(rows[i].icon, size: 13, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rows[i].label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (rows[i].value != null) ...[
                  Text(
                    rows[i].value!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Broken.arrow_right_3,
                    size: 11,
                    color: Colors.white38,
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.brightness_6_rounded, size: 13, color: Colors.white54),
              const SizedBox(width: 8),
              const Text(
                'Luminosité',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.nightlight_round, size: 11, color: Colors.white38),
              const SizedBox(width: 6),
              SizedBox(
                width: 90,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: brightness,
                    onChanged: onBrightnessChanged,
                    activeColor: accent,
                    inactiveColor: Colors.white.withValues(alpha: .12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.brightness_2_rounded, size: 13, color: Colors.white54),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mode nuit',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: nightMode,
                onChanged: onNightModeChanged,
                activeThumbColor: accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 9. MangaPageProgressCard ────────────────────────────────────────────
/// Avancement global de la lecture (anneau).
class MangaPageProgressCard extends StatelessWidget {
  const MangaPageProgressCard({
    super.key,
    required this.percentLabel,
    this.progress = 0,
    this.chapterLabel,
    this.pageLabel,
    this.width = 280,
  });

  ///(`20%`).
  final String percentLabel;
  final double progress;
  final String? chapterLabel;
  final String? pageLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withValues(alpha: .08),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
                Center(
                  child: Text(
                    percentLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapterLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pageLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: .08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 10. MangaReadingProgressCard ────────────────────────────────────────
/// Suivi de la progression du chapitre (variante avec marque-page).
class MangaReadingProgressCard extends StatelessWidget {
  const MangaReadingProgressCard({
    super.key,
    required this.title,
    this.chapterLabel,
    this.pageLabel,
    this.percentLabel,
    this.progress = 0,
    this.coverUrl,
    this.width = 300,
    this.onBookmark,
  });

  final String title;
  final String? chapterLabel;
  final String? pageLabel;
  final String? percentLabel;
  final double progress;
  final String? coverUrl;
  final double width;
  final VoidCallback? onBookmark;

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
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: ContentImage(url: coverUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapterLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: .08),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          percentLabel ?? '',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pageLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onBookmark,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.bookmark_rounded,
                    size: 16,
                    color: accent,
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

/// ── 11. MangaChapterNavigationCard ──────────────────────────────────────
/// Navigation entre chapitres.
class MangaChapterNavigationCard extends StatelessWidget {
  const MangaChapterNavigationCard({
    super.key,
    required this.currentLabel,
    this.prevLabel,
    this.prevSub,
    this.nextLabel,
    this.nextSub,
    this.width = 420,
    this.onPrev,
    this.onNext,
  });

  final String currentLabel;
  final String? prevLabel;
  final String? prevSub;
  final String? nextLabel;
  final String? nextSub;
  final double width;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPrev,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 12,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prevLabel ?? 'Chapitre précédent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      prevSub ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: accent.withValues(alpha: .5)),
              ),
              child: Text(
                currentLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onNext,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Broken.arrow_right_3,
                      size: 12,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextLabel ?? 'Chapitre suivant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      nextSub ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 12. MangaQuickAccessCard ────────────────────────────────────────────
/// Accès rapide aux derniers chapitres lus + raccourcis.
class MangaQuickAccessCard extends StatelessWidget {
  const MangaQuickAccessCard({
    super.key,
    required this.resumeTitle,
    this.resumeChapter,
    this.resumePage,
    this.resumeThumb,
    required this.actions,
    this.shortcutsTitle = 'Raccourcis',
    required this.shortcuts,
    this.width = 340,
    this.onResume,
  });

  final String resumeTitle;
  final String? resumeChapter;
  final String? resumePage;
  final String? resumeThumb;
  final List<MangaQuickAction> actions;
  final String shortcutsTitle;
  final List<MangaQuickAction> shortcuts;
  final double width;
  final VoidCallback? onResume;

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
          _CardTitle(
            'Accès rapide',
            'Reprends là où tu t’es arrêté.',
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onResume,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: accent.withValues(alpha: .3)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 52,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ContentImage(
                        url: resumeThumb,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reprendre la lecture',
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          resumeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${resumeChapter ?? ''} · ${resumePage ?? ''}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Broken.play,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          actions[i].icon,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            actions[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            shortcutsTitle,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in shortcuts)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, size: 12, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text(
                        s.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 13. MangaReaderFloatingCard ─────────────────────────────────────────
/// Contrôles rapides en lecture.
class MangaReaderFloatingCard extends StatelessWidget {
  const MangaReaderFloatingCard({
    super.key,
    required this.bgUrl,
    required this.chapterLabel,
    this.prevLabel,
    this.nextLabel,
    required this.actions,
    this.width = 340,
  });

  final String? bgUrl;
  final String chapterLabel;
  final String? prevLabel;
  final String? nextLabel;
  final List<MangaQuickAction> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(8),
      decoration: _panelDecoration(accent, radius: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Positioned.fill(
              child: ContentImage(url: bgUrl, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.15, .55, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black45,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_rounded,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        prevLabel ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        chapterLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        nextLabel ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Broken.arrow_right_3,
                        size: 12,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15171D).withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final a in actions)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(a.icon, size: 14, color: Colors.white70),
                              const SizedBox(height: 3),
                              Text(
                                a.label,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
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

/// ── 14. MangaReaderChapterListCard ──────────────────────────────────────
/// Liste des chapitres d'un manga (filtres Tous / Lu / Non lu).
class MangaReaderChapterListCard extends StatelessWidget {
  const MangaReaderChapterListCard({
    super.key,
    required this.items,
    this.countLabel,
    this.width = 300,
    this.onRead,
  });

  final List<MangaReaderChapterRow> items;
  final String? countLabel;
  final double width;
  final VoidCallback? onRead;

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
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tous',
                      selected: true,
                      accent: accent,
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Lu',
                      selected: false,
                      accent: accent,
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Non lu',
                      selected: false,
                      accent: accent,
                    ),
                  ],
                ),
              ),
              Text(
                countLabel ?? '${items.length}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ReaderChapterRow(item: items[i], onRead: onRead),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
  });

  final String label;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? accent : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white54,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReaderChapterRow extends StatelessWidget {
  const _ReaderChapterRow({required this.item, this.onRead});

  final MangaReaderChapterRow item;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 46,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ContentImage(url: item.thumbUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 9,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.timeAgo ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (item.showReadButton)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Lire',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            Row(
              children: [
                Icon(
                  Broken.tick_circle,
                  size: 11,
                  color: Colors.white38,
                ),
                const SizedBox(width: 3),
                const Text(
                  'Lu',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// ── 15. MangaReaderHistoryCard ──────────────────────────────────────────
/// Historique de lecture.
class MangaReaderHistoryCard extends StatelessWidget {
  const MangaReaderHistoryCard({
    super.key,
    required this.items,
    this.width = 300,
    this.onSeeAll,
  });

  final List<MangaReaderHistoryEntry> items;
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
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Ton historique de lecture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
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
                        Icon(
                          Broken.arrow_right_3,
                          size: 12,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _HistoryRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final MangaReaderHistoryEntry item;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 50,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ContentImage(url: item.thumbUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.subtitle ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          minHeight: 3,
                          backgroundColor:
                              Colors.white.withValues(alpha: .08),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.percentLabel ?? '',
                      style: TextStyle(
                        color: accent,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Broken.arrow_right_3,
            size: 12,
            color: Colors.white38,
          ),
        ],
      ),
    );
  }
}
