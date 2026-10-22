import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

/// Denseur d'affichage choisi dans la section « Affichage » de la feuille.
enum CatalogLayout { grid, comfortable, list }

/// Un choix de la section « Type » (ex. Film, Série, Animation…).
class CatalogTypeOption {
  final String label;
  final String value;
  const CatalogTypeOption(this.label, this.value);
}

/// Un choix de la section « Ordre ».
class CatalogSortOption {
  final String label;
  final String value;
  const CatalogSortOption(this.label, this.value);
}

/// État de filtres partagé par la coquille catalogue « voir tout ».
/// Réutilisable par TMDB, AniList et les extensions.
class CatalogFilterState {
  /// `'all'` ou la valeur d'une [CatalogTypeOption] du mode courant.
  String type;

  /// Années minimale / maximale incluses ; `null` = sans filtre d'années.
  int? minYear;
  int? maxYear;

  /// Note minimale (0 = toutes les notes).
  double minRating;

  /// Genres sélectionnés (libellés exacts, comparaison insensible à la casse).
  final Set<String> genres;

  /// Clé d'une [CatalogSortOption].
  String sortMode;

  /// Densité d'affichage de la grille.
  CatalogLayout layout;

  CatalogFilterState({
    this.type = 'all',
    this.minYear,
    this.maxYear,
    this.minRating = 0,
    Set<String>? genres,
    this.sortMode = 'popular',
    this.layout = CatalogLayout.grid,
  }) : genres = {...?genres};

  CatalogFilterState copy() =>
      CatalogFilterState()
        ..type = type
        ..minYear = minYear
        ..maxYear = maxYear
        ..minRating = minRating
        ..genres.addAll(genres)
        ..sortMode = sortMode
        ..layout = layout;

  void reset() {
    type = 'all';
    minYear = null;
    maxYear = null;
    minRating = 0;
    genres.clear();
    sortMode = 'popular';
    layout = CatalogLayout.grid;
  }

  bool get isDefault =>
      type == 'all' &&
      minYear == null &&
      maxYear == null &&
      minRating <= 0 &&
      genres.isEmpty &&
      sortMode == 'popular' &&
      layout == CatalogLayout.grid;

  /// Une année donnée passe-t-elle le filtre d'années ? Un item sans année
  /// n'est masqué que si l'utilisateur a explicitement borné les années.
  bool matchesYears(int? year) {
    if (minYear == null && maxYear == null) return true;
    if (year == null) return false;
    if (minYear != null && year < minYear!) return false;
    if (maxYear != null && year > maxYear!) return false;
    return true;
  }

  /// Les genres d'un item couvrent-ils tous les genres sélectionnés ?
  bool matchesGenres(Iterable<String> itemGenres) {
    if (genres.isEmpty) return true;
    final lowercase = itemGenres.map((g) => g.toLowerCase()).toSet();
    return genres.every((g) => lowercase.contains(g.toLowerCase()));
  }
}

/// Ouvre la feuille de filtres multi-niveaux réutilisable (même chrome que la
/// feuille de filtres de la page Librairie : poignée, « Réinitialiser »,
/// boutons « Annuler » / « Appliquer », sections repliables).
///
/// Renvoie la nouvelle valeur de filtres, ou `null` si annulée.
Future<CatalogFilterState?> showCatalogFilterSheet(
  BuildContext context, {
  required CatalogFilterState initial,
  required List<CatalogTypeOption> typeOptions,
  required List<CatalogSortOption> sortOptions,
  List<String> genreOptions = const [],
  bool showTypeSection = true,
  bool showYearsSection = true,
  bool showRatingSection = true,
  bool showGenreSection = true,
  bool showSortSection = true,
  bool showLayoutSection = true,
}) {
  return showModalBottomSheet<CatalogFilterState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CatalogFilterSheet(
      initial: initial,
      typeOptions: typeOptions,
      sortOptions: sortOptions,
      genreOptions: genreOptions,
      showTypeSection: showTypeSection,
      showYearsSection: showYearsSection,
      showRatingSection: showRatingSection,
      showGenreSection: showGenreSection,
      showSortSection: showSortSection,
      showLayoutSection: showLayoutSection,
    ),
  );
}

class _CatalogFilterSheet extends StatefulWidget {
  final CatalogFilterState initial;
  final List<CatalogTypeOption> typeOptions;
  final List<CatalogSortOption> sortOptions;
  final List<String> genreOptions;
  final bool showTypeSection;
  final bool showYearsSection;
  final bool showRatingSection;
  final bool showGenreSection;
  final bool showSortSection;
  final bool showLayoutSection;

  const _CatalogFilterSheet({
    required this.initial,
    required this.typeOptions,
    required this.sortOptions,
    required this.genreOptions,
    required this.showTypeSection,
    required this.showYearsSection,
    required this.showRatingSection,
    required this.showGenreSection,
    required this.showSortSection,
    required this.showLayoutSection,
  });

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late CatalogFilterState _draft = widget.initial.copy();

  bool get _hasActiveFilters {
    final d = _draft;
    return d.type != 'all' ||
        d.minYear != null ||
        d.maxYear != null ||
        d.minRating > 0 ||
        d.genres.isNotEmpty;
  }

  CatalogTypeOption? get _typeOption => widget.typeOptions
      .where((o) => o.value == _draft.type)
      .cast<CatalogTypeOption?>()
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C1E) : cs.surface;

    final sections = <Widget>[
      if (widget.showLayoutSection)
        _AffichageSection(layout: _draft.layout, onChanged: (v) => setState(() => _draft.layout = v)),
      if (widget.showTypeSection && widget.typeOptions.isNotEmpty)
        _ChipsSection(
          title: 'Type',
          value: _typeOption?.label ?? _draft.type,
          groups: [
            _ChipGroup.single(
              options: [
                for (final o in widget.typeOptions)
                  (
                    o.label,
                    o.value,
                    selected: _draft.type == o.value,
                    onTap: () => setState(() => _draft.type = o.value),
                  ),
              ],
            ),
          ],
        ),
      if (widget.showYearsSection) _buildYearsSection(),
      if (widget.showGenreSection && widget.genreOptions.isNotEmpty)
        _ChipsSection(
          title: 'Genres',
          value: _draft.genres.isEmpty
              ? null
              : '${_draft.genres.length} sélectionné(s)',
          groups: [
            _ChipGroup.multi(
              options: [
                for (final genre in widget.genreOptions)
                  (
                    genre,
                    genre,
                    selected: _draft.genres.contains(genre),
                    onTap: () => setState(() {
                      _draft.genres.contains(genre)
                          ? _draft.genres.remove(genre)
                          : _draft.genres.add(genre);
                    }),
                  ),
              ],
            ),
          ],
        ),
      if (widget.showRatingSection)
        _ChipsSection(
          title: 'Note',
          value: _draft.minRating > 0              ? '${_draft.minRating.toInt()}+'
              : null,
          groups: [
            _ChipGroup.single(
              options: [
                for (final (rating, label) in const [(0.0, 'Toutes'), (6.0, '6+'), (7.0, '7+'), (8.0, '8+'), (9.0, '9+')])
                  (
                    label,
                    '${rating.toInt()}',
                    selected: _draft.minRating == rating,
                    onTap: () => setState(() => _draft.minRating = rating),
                  ),
              ],
            ),
          ],
        ),
      if (widget.showSortSection)
        _ChipsSection(
          title: 'Ordre',
          value: widget.sortOptions
              .where((o) => o.value == _draft.sortMode)
              .map((o) => o.label)
              .firstOrNull,
          groups: [
            _ChipGroup.single(
              options: [
                for (final o in widget.sortOptions)
                  (
                    o.label,
                    o.value,
                    selected: _draft.sortMode == o.value,
                    onTap: () => setState(() => _draft.sortMode = o.value),
                  ),
              ],
            ),
          ],
        ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Filtres',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: cs.onSurface,
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Text(
                      'actifs',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _draft.reset()),
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: sections,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _draft),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Appliquer'),
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

  Widget _buildYearsSection() {
    final now = DateTime.now().year;
    final decadeSelected = (int start) =>
        _draft.minYear == start && _draft.maxYear == start + 9;
    return _ChipsSection(
      title: 'Années',
      value: _draft.minYear == null && _draft.maxYear == null
          ? null
          : _draft.minYear == _draft.maxYear
          ? '$_draft.minYear'
          : '${_draft.minYear ?? '…'} — ${_draft.maxYear ?? '…'}',
      groups: [
        _ChipGroup.single(
          options: [
            (
              'Tout',
              'all',
              selected: _draft.minYear == null && _draft.maxYear == null,
              onTap: () => setState(() {
                _draft.minYear = null;
                _draft.maxYear = null;
              }),
            ),
            for (final (label, start, end) in const [
              ('2020s', 2020, 2029),
              ('2010s', 2010, 2019),
              ('2000s', 2000, 2009),
              ('Classique', 0, 1999),
            ])
              (
                label,
                '$start-$end',
                selected: label == 'Classique'
                    ? (_draft.minYear == null && _draft.maxYear == 1999)
                    : decadeSelected(start),
                onTap: () => setState(() {
                  if (label == 'Classique') {
                    final active =
                        _draft.minYear == null && _draft.maxYear == 1999;
                    _draft.minYear = active ? null : 0;
                    _draft.maxYear = active ? null : 1999;
                  } else {
                    final active = decadeSelected(start);
                    _draft.minYear = active ? null : start;
                    _draft.maxYear = active ? null : end;
                  }
                }),
              ),
          ],
        ),
        _ChipGroup.sub(
          subTitle: 'Toutes les années',
          options: [
            for (var year = now; year >= 2000; year--)
              (
                '$year',
                'year',
                selected: _draft.minYear == year && _draft.maxYear == year,
                onTap: () => setState(() {
                  final active =
                      _draft.minYear == year && _draft.maxYear == year;
                  _draft.minYear = active ? null : year;
                  _draft.maxYear = active ? null : year;
                }),
              ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sections réutilisables (sections + sous-sections)
// ─────────────────────────────────────────────────────────────────────────────

typedef _Chip = (String, String, {bool selected, VoidCallback onTap});

/// Un groupe de puces mono- ou multi-sélection présenté dans une section.
class _ChipGroup {
  final bool multi;
  final List<_Chip> options;

  /// Titre d'une sous-section repliable contenant [options].
  final String? subTitle;

  const _ChipGroup.single({required this.options})
      : multi = false,
        subTitle = null;
  const _ChipGroup.multi({required this.options})
      : multi = true,
        subTitle = null;
  const _ChipGroup.sub({required this.subTitle, required this.options})
      : multi = false;
}

/// Bloc « Titre + sous-titre (valeur active) + groupes de puces », avec ou
/// sans sous-section repliable.
class _ChipsSection extends StatelessWidget {
  final String title;
  final String? value;
  final List<_ChipGroup> groups;

  const _ChipsSection({
    required this.title,
    required this.groups,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (final group in groups) {
      final subTitle = group.subTitle;
      if (subTitle != null) {
        children.add(
          _SubSection(
            title: subTitle,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in group.options) _buildChip(context, chip, group),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in group.options) _buildChip(context, chip, group),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (value != null) ...[
                const Spacer(),
                Text(
                  value!,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SubSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SubSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        collapsedBackgroundColor: cs.onSurface.withValues(alpha: 0.04),
        backgroundColor: cs.onSurface.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.onSurface.withValues(alpha: 0.10)),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.onSurface.withValues(alpha: 0.10)),
        ),
        iconColor: cs.onSurfaceVariant,
        collapsedIconColor: cs.onSurfaceVariant,
        initiallyExpanded: false,
        title: Text(
          title,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [child],
      ),
    );
  }
}

class _AffichageSection extends StatelessWidget {
  final CatalogLayout layout;
  final ValueChanged<CatalogLayout> onChanged;

  const _AffichageSection({required this.layout, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = const [
      ('Grille', CatalogLayout.grid, Icons.grid_view_rounded),
      ('Confortable', CatalogLayout.comfortable, Icons.calendar_view_day_rounded),
      ('Liste', CatalogLayout.list, Icons.view_agenda_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Affichage',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<CatalogLayout>(
            showSelectedIcon: false,
            segments: [
              for (final (label, mode, icon) in options)
                ButtonSegment(
                  value: mode,
                  icon: Icon(icon, size: 16),
                  label: Text(label),
                ),
            ],
            selected: {layout},
            onSelectionChanged: (selection) => onChanged(selection.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              side: WidgetStatePropertyAll(
                BorderSide(color: cs.onSurface.withValues(alpha: 0.12)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? cs.primary.withValues(alpha: 0.16)
                      : Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildChip(BuildContext context, _Chip chip, _ChipGroup group) {
  final cs = Theme.of(context).colorScheme;
  final selected = chip.selected;
  final onTap = chip.onTap;
  final color = selected
      ? cs.primary
      : cs.onSurface.withValues(alpha: 0.12);
  final labelStyle = TextStyle(
    color: selected ? cs.primary : cs.onSurface,
    fontSize: 12,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
  );
  return ActionChip(
    visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
    side: BorderSide(color: color),
    backgroundColor: selected
        ? cs.primary.withValues(alpha: 0.12)
        : Colors.transparent,
    avatar: selected
        ? Icon(group.multi ? Icons.check_rounded : Icons.circle_rounded, size: group.multi ? 14 : 8, color: cs.primary)
        : null,
    label: Text(chip.$1, style: labelStyle),
    onPressed: onTap,
  );
}
