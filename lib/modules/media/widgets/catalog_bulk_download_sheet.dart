import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart'
    show QualityFallback;
import 'package:watchtower/modules/media/extension_image_headers.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/cover_url.dart';

/// One catalogue entry resolved for the batch: its detail, the episodes kept
/// and the quality/language to download them in.
class BulkDownloadItem {
  BulkDownloadItem({
    required this.item,
    required this.detail,
    required this.chapters,
    this.quality,
    this.language,
    this.fallback = QualityFallback.exact,
  });

  final MManga item;
  final MManga detail;
  final List<MChapter> chapters;
  final String? quality;
  final String? language;

  /// Strategy used by the engine when [quality] is absent from the episode's
  /// real video list (supérieure / inférieure / exacte).
  final QualityFallback fallback;
}

/// Everything the batch needs to start, once the user confirmed the sheet.
class BulkDownloadPlan {
  const BulkDownloadPlan({required this.items});

  final List<BulkDownloadItem> items;
}

const LinearGradient _kSheetGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF1EA7EF), Color(0xFF36E07D)],
);

/// Formats offered when an extension does not declare any.
const List<String> _kDefaultQualities = [
  '144p',
  '240p',
  '360p',
  '480p',
  '720p',
  '1080p',
];

/// Opens the batch configuration sheet: one row per catalogue video with its
/// own quality box, plus a header that applies a single quality/language to the
/// whole batch. Returns null when the user backs out.
Future<BulkDownloadPlan?> showCatalogBulkDownloadSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Source source,
  required List<MManga> items,
}) {
  return showModalBottomSheet<BulkDownloadPlan>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 0,
    builder: (_) => _CatalogBulkDownloadSheet(
      ref: ref,
      source: source,
      items: items,
    ),
  );
}

class _ResolvedVideo {
  _ResolvedVideo(this.item);
  final MManga item;
  MManga? detail;
  List<MChapter> chapters = const [];
  Set<int> selected = {};
  String? quality;
  String? language;

  /// Season label picked for this series (`S01`, …), or null for "Toutes".
  String? season;
  List<String> seasons = const [];
  bool loading = true;
  String? error;

  /// Whether the row's episode list is unfolded (drives the chevron).
  bool expanded = false;

  /// Episode indices currently shown, i.e. those of [seasons]-matching
  /// [season] when one is picked.
  List<int> get visibleIndices {
    if (season == null) return [for (var i = 0; i < chapters.length; i++) i];
    return [
      for (var i = 0; i < chapters.length; i++)
        if (seasonOf(chapters[i].name) == season) i,
    ];
  }
}

/// Seasons declared by a list of episode names, as `S01`-style labels, sorted.
List<String> _seasonsOf(List<MChapter> chapters) {
  final found = <String>{
    for (final chapter in chapters)
      if (seasonOf(chapter.name) != null) seasonOf(chapter.name)!,
  };
  final list = found.toList()..sort();
  return list;
}

/// Extracts the `Sxx` season marker of an episode name, or null when the name
/// carries none (extensions often number episodes without a season).
String? seasonOf(String? name) {
  final raw = (name ?? '').trim();
  if (raw.isEmpty) return null;
  final m = RegExp(r'(?:^|[^A-Za-z0-9])S\s?(\d{1,3})(?![0-9])',
          caseSensitive: false)
      .firstMatch(raw);
  if (m == null) return null;
  return 'S${m.group(1)!.padLeft(2, '0')}';
}

class _CatalogBulkDownloadSheet extends StatefulWidget {
  const _CatalogBulkDownloadSheet({
    required this.ref,
    required this.source,
    required this.items,
  });

  final WidgetRef ref;
  final Source source;
  final List<MManga> items;

  @override
  State<_CatalogBulkDownloadSheet> createState() =>
      _CatalogBulkDownloadSheetState();
}

class _CatalogBulkDownloadSheetState extends State<_CatalogBulkDownloadSheet> {
  late final List<_ResolvedVideo> _rows;
  late final List<String> _formats;
  String? _bulkQuality;
  QualityFallback _bulkFallback = QualityFallback.higher;
  String? _bulkLanguage;
  String? _bulkSeason;
  bool _busy = true;

  /// Languages offered in the sheet's language boxes.
  static const List<String> _kLanguages = [
    'VF',
    'VOSTFR',
    'VO',
    'MULTI',
    'EN',
    'FR',
  ];

  /// Every season declared by the resolved series, for the header box.
  List<String> get _headerSeasons {
    final found = <String>{
      for (final row in _rows) ...row.seasons,
    };
    return found.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    final declared = (widget.source.videoQualities ?? const <String>[])
        .map(_normQuality)
        .where((q) => _resRank(q) >= 144)
        .toSet()
        .toList()
      ..sort((a, b) => _resRank(a).compareTo(_resRank(b)));
    _formats = declared.isNotEmpty ? declared : _kDefaultQualities;
    _rows = widget.items.map(_ResolvedVideo.new).toList();
    _resolveAll();
  }

  Future<void> _resolveAll() async {
    await Future.wait(_rows.map(_resolveOne));
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _resolveOne(_ResolvedVideo row) async {
    final url = row.item.link?.trim();
    if (url == null || url.isEmpty) {
      row
        ..loading = false
        ..error = 'Lien manquant';
      return;
    }
    try {
      final detail = await widget.ref.read(
        getDetailProvider(url: url, source: widget.source).future,
      );
      final chapters = [
        for (final c in detail.chapters ?? const <MChapter>[])
          if ((c.url ?? '').trim().isNotEmpty) c,
      ];
      row.detail = detail;
      row.chapters = chapters;
      row.seasons = _seasonsOf(chapters);
      row.selected = {for (var i = 0; i < chapters.length; i++) i};
    } catch (e) {
      row
        ..loading = false
        ..error = e.toString();
    }
    if (mounted) setState(() => row.loading = false);
  }

  /// Applies the header selection to every row. A missing resolution is
  /// replaced by the closest one above/below according to [_bulkFallback].
  void _applyBulkQuality(String? target) {
    setState(() {
      _bulkQuality = target;
      for (final row in _rows) {
        row.quality = target == null
            ? null
            : _resolveQuality(_formats, target, _bulkFallback);
      }
    });
  }

  void _applyBulkFallback(QualityFallback fallback) {
    setState(() => _bulkFallback = fallback);
    if (_bulkQuality != null) _applyBulkQuality(_bulkQuality);
  }

  void _applyBulkLanguage(String? language) {
    setState(() {
      _bulkLanguage = language;
      for (final row in _rows) {
        row.language = language;
      }
    });
  }

  /// Header season pick: sets each row's season and reselects only its
  /// matching episodes, so the batch really only keeps that season.
  void _applyBulkSeason(String? season) {
    setState(() {
      _bulkSeason = season;
      for (final row in _rows) {
        row.season = season;
        final visible = row.visibleIndices;
        row.selected = {...visible};
      }
    });
  }

  int get _totalSelected =>
      _rows.fold(0, (sum, row) => sum + row.selected.length);

  void _confirm() {
    final items = <BulkDownloadItem>[];
    for (final row in _rows) {
      if (row.detail == null) continue;
      final chapters = [
        for (var i = 0; i < row.chapters.length; i++)
          if (row.selected.contains(i)) row.chapters[i],
      ];
      if (chapters.isEmpty) continue;
      items.add(
        BulkDownloadItem(
          item: row.item,
          detail: row.detail!,
          chapters: chapters,
          quality: row.quality,
          language: row.language,
          fallback: _bulkFallback,
        ),
      );
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune vidéo sélectionnée.')),
      );
      return;
    }
    Navigator.of(context).pop(BulkDownloadPlan(items: items));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height * 0.86;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          _header(cs),
          if (_busy)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: _rows.length,
                itemBuilder: (context, i) => _rowCard(_rows[i], cs),
              ),
            ),
          _footer(cs),
        ],
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Télécharger ${widget.items.length} vidéo(s)',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _BulkDropdown<String?>(
                  label: 'Qualité (toutes)',
                  value: _bulkQuality,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Auto (meilleure)'),
                    ),
                    for (final q in _formats)
                      DropdownMenuItem<String?>(value: q, child: Text(q)),
                  ],
                  onChanged: _applyBulkQuality,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BulkDropdown<QualityFallback>(
                  label: 'Si absente',
                  value: _bulkFallback,
                  items: const [
                    DropdownMenuItem(
                      value: QualityFallback.higher,
                      child: Text('Supérieure'),
                    ),
                    DropdownMenuItem(
                      value: QualityFallback.lower,
                      child: Text('Inférieure'),
                    ),
                    DropdownMenuItem(
                      value: QualityFallback.exact,
                      child: Text('Exacte'),
                    ),
                  ],
                  onChanged: (v) => _applyBulkFallback(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BulkDropdown<String?>(
                  label: 'Langue (toutes)',
                  value: _bulkLanguage,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes les langues'),
                    ),
                    for (final l in _kLanguages)
                      DropdownMenuItem<String?>(value: l, child: Text(l)),
                  ],
                  onChanged: _applyBulkLanguage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BulkDropdown<String?>(
                  label: 'Saison (toutes)',
                  value: _bulkSeason,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Toutes'),
                    ),
                    for (final s in _headerSeasons)
                      DropdownMenuItem<String?>(value: s, child: Text(s)),
                  ],
                  onChanged: _applyBulkSeason,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rowCard(_ResolvedVideo row, ColorScheme cs) {
    final isSeries = row.chapters.length > 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          onExpansionChanged: (value) => setState(() => row.expanded = value),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _cover(row.item),
          ),
          title: Text(
            row.item.name?.trim().isNotEmpty == true
                ? row.item.name!.trim()
                : 'Vidéo',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            row.loading
                ? 'Récupération des formats…'
                : row.error != null
                ? 'Format indisponible'
                : isSeries
                ? '${row.selected.length}/${row.chapters.length} épisodes'
                : '1 vidéo',
            style: TextStyle(
              color: row.error != null ? mbRed : cs.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
          trailing: _qualityBox(row),
          children: [
            if (row.error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  row.error!,
                  style: const TextStyle(color: mbRed, fontSize: 11.5),
                ),
              )
            else if (isSeries) ...[
              Row(
                children: [
                  Expanded(
                    child: _BulkDropdown<String?>(
                      label: 'Langue',
                      value: row.language,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Toutes'),
                        ),
                        for (final l in _kLanguages)
                          DropdownMenuItem<String?>(
                            value: l,
                            child: Text(l),
                          ),
                      ],
                      onChanged: (v) => setState(() => row.language = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BulkDropdown<String?>(
                      label: 'Saison',
                      value: row.season,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Toutes'),
                        ),
                        for (final s in row.seasons)
                          DropdownMenuItem<String?>(
                            value: s,
                            child: Text(s),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        row.season = v;
                        row.selected = {...row.visibleIndices};
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Épisodes',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      final visible = row.visibleIndices;
                      if (visible.every(row.selected.contains)) {
                        row.selected.removeAll(visible);
                      } else {
                        row.selected.addAll(visible);
                      }
                    }),
                    child: Text(
                      row.visibleIndices.every(row.selected.contains)
                          ? 'Tout décocher'
                          : 'Tout cocher',
                    ),
                  ),
                ],
              ),
              for (final i in row.visibleIndices)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: row.selected.contains(i),
                  title: Text(
                    row.chapters[i].name?.trim().isNotEmpty == true
                        ? row.chapters[i].name!.trim()
                        : 'Épisode ${i + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurface, fontSize: 12.5),
                  ),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      row.selected.add(i);
                    } else {
                      row.selected.remove(i);
                    }
                  }),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cover(MManga item) {
    final url = normalizeCoverUrl(item.imageUrl);
    if (url == null || url.isEmpty) {
      return Container(
        width: 44,
        height: 60,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie_outlined, size: 18),
      );
    }
    return cachedNetworkImage(
      imageUrl: url,
      width: 44,
      height: 60,
      fit: BoxFit.cover,
      headers: ExtensionImageHeaders.of(context),
      errorWidget: const Icon(Icons.movie_outlined, size: 18),
    );
  }

  /// Per-video quality box, pinned at the right end of the row, followed by the
  /// chevron that unfolds the episode picker (series only).
  Widget _qualityBox(_ResolvedVideo row) {
    final cs = Theme.of(context).colorScheme;
    if (row.loading || row.error != null) {
      return Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant);
    }
    final options = <String?>[null, ..._formats];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: options.contains(row.quality) ? row.quality : null,
              style: TextStyle(color: cs.onSurface, fontSize: 12.5),
              items: [
                for (final q in options)
                  DropdownMenuItem<String?>(
                    value: q,
                    child: Text(
                      q ?? 'Auto',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => row.quality = v),
            ),
          ),
        ),
        AnimatedRotation(
          turns: row.expanded ? 0.25 : 0,
          duration: const Duration(milliseconds: 180),
          child: Icon(
            Icons.chevron_right_rounded,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _footer(ColorScheme cs) {
    final enabled = !_busy && _totalSelected > 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton(
            onPressed: enabled ? _confirm : null,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled ? _kSheetGradient : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Mettre en file d’attente ($_totalSelected)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled dropdown used by the batch header.
class _BulkDropdown<T> extends StatelessWidget {
  const _BulkDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              items: items,
              onChanged: (v) => onChanged(v as T),
              style: TextStyle(color: cs.onSurface, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Resolves [target] against the [available] resolutions using [fallback].
String? _resolveQuality(
  List<String> available,
  String target,
  QualityFallback fallback,
) {
  if (available.isEmpty) return target;
  final targetRank = _resRank(target);
  final ranked = [
    for (final q in available) (label: q, rank: _resRank(q)),
  ]..sort((a, b) => a.rank.compareTo(b.rank));
  for (final q in ranked) {
    if (q.rank == targetRank) return q.label;
  }
  switch (fallback) {
    case QualityFallback.exact:
      return target;
    case QualityFallback.higher:
      for (final q in ranked) {
        if (q.rank > targetRank) return q.label;
      }
      return ranked.last.label;
    case QualityFallback.lower:
      for (final q in ranked.reversed) {
        if (q.rank < targetRank) return q.label;
      }
      return ranked.first.label;
  }
}

String _normQuality(String raw) {
  if (raw.trim().isEmpty) return 'Auto';
  final s = raw.toLowerCase();
  if (s.contains('8k') || s.contains('4320')) return '8K';
  if (s.contains('4k') || s.contains('2160')) return '4K';
  final resolution = RegExp(
    r'(1440|1080|720|540|480|360|240)\s*p?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (resolution != null) return '${resolution.group(1)}p';
  return raw.trim();
}

int _resRank(String label) {
  final m = RegExp(r'(\d{3,4})').firstMatch(label);
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
}
