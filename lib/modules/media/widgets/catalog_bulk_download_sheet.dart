import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/models/chapter.dart' as db_chapter;
import 'package:watchtower/models/manga.dart' as db_manga;
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/app_ui_components.dart' show AppShimmerBlock;
import 'package:watchtower/modules/manga/download/providers/download_provider.dart'
    show QualityFallback;
import 'package:watchtower/modules/media/extension_image_headers.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/services/get_video_list.dart';
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
    builder: (_) => _CatalogBulkDownloadSheet(ref: ref, source: source, items: items),
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
  List<String> qualities = const [];
  List<String> languages = const [];
  bool formatsLoading = false;

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
  final m = RegExp(
    r'\b(?:S(?:aison)?|Season)\s*(\d{1,3})(?![0-9])',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  return 'Saison ${int.parse(m.group(1)!)}';
}

class _CatalogBulkDownloadSheet extends StatefulWidget {
  const _CatalogBulkDownloadSheet({required this.ref, required this.source, required this.items});

  final WidgetRef ref;
  final Source source;
  final List<MManga> items;

  @override
  State<_CatalogBulkDownloadSheet> createState() => _CatalogBulkDownloadSheetState();
}

class _CatalogBulkDownloadSheetState extends State<_CatalogBulkDownloadSheet> {
  late final List<_ResolvedVideo> _rows;
  String? _bulkQuality;
  QualityFallback _bulkFallback = QualityFallback.higher;
  String? _bulkLanguage;
  String? _bulkSeason;

  static final RegExp _languageInQuality = RegExp(
    r'\b(VOSTFR|VOSTA|MULTI|ENGLISH|FRENCH|FRANÇAIS|SPANISH|ESPAÑOL|'
    r'JAPANESE|JAPONAIS|PORTUGUESE|PORTUGAIS|GERMAN|DEUTSCH|ITALIAN|'
    r'ITALIANO|KOREAN|CHINESE|ARABIC|RUSSIAN|VF|VO|EN|FR|JAP?|ENG?)\b',
    caseSensitive: false,
  );

  /// Every season declared by the resolved series, for the header box.
  List<String> get _headerSeasons {
    final found = <String>{for (final row in _rows) ...row.seasons};
    return found.toList()..sort();
  }

  List<String> get _formats {
    final values = <String>{
      for (final quality in widget.source.videoQualities ?? const <String>[])
        if (_normQuality(quality).trim().isNotEmpty) _normQuality(quality),
      for (final row in _rows) ...row.qualities,
    };
    return values.toList()..sort((a, b) => _resRank(a).compareTo(_resRank(b)));
  }

  List<String> _qualitiesFor(_ResolvedVideo row) {
    if (row.qualities.isNotEmpty) return row.qualities;
    return (widget.source.videoQualities ?? const <String>[])
        .map(_normQuality)
        .where((quality) => quality.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => _resRank(a).compareTo(_resRank(b)));
  }

  List<String> get _headerLanguages {
    final values = <String>{};
    final keys = <String>{};
    for (final row in _rows) {
      for (final language in row.languages) {
        if (keys.add(language.toLowerCase())) values.add(language);
      }
    }
    return values.toList()..sort();
  }

  bool get _resolvingRows => _rows.any((row) => row.loading);

  @override
  void initState() {
    super.initState();
    _rows = widget.items.map(_ResolvedVideo.new).toList();
    unawaited(_resolveAll());
  }

  Future<void> _resolveAll() async {
    var next = 0;
    Future<void> worker() async {
      while (next < _rows.length) {
        final row = _rows[next++];
        await _resolveOne(row);
      }
    }

    final workers = _rows.length < 4 ? _rows.length : 4;
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
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
      row.season = _bulkSeason;
      row.selected = {...row.visibleIndices};
      row.loading = false;
      if (mounted) setState(() {});
      await _loadVideoOptions(row, detail);
    } catch (e) {
      row
        ..loading = false
        ..error = e.toString();
    }
    if (mounted) setState(() => row.loading = false);
  }

  Future<void> _loadVideoOptions(_ResolvedVideo row, MManga detail) async {
    if (row.chapters.isEmpty) return;
    row.formatsLoading = true;
    if (mounted) setState(() {});
    try {
      final first = row.chapters.first;
      final manga = db_manga.Manga(
        source: widget.source.name ?? '',
        author: detail.author ?? '',
        artist: detail.artist ?? '',
        genre: detail.genre ?? row.item.genre,
        imageUrl: detail.imageUrl ?? row.item.imageUrl,
        lang: widget.source.lang ?? '',
        link: row.item.link,
        name: detail.name ?? row.item.name ?? '',
        status: db_manga.Status.unknown,
        description: detail.description ?? '',
        sourceId: widget.source.id,
        itemType: widget.source.itemType,
        isManga: widget.source.itemType == db_manga.ItemType.manga,
      );
      final episode = db_chapter.Chapter(
        mangaId: manga.id,
        name: first.name ?? row.item.name,
        url: first.url,
        dateUpload: first.dateUpload,
        scanlator: first.scanlator,
        thumbnailUrl: first.thumbnailUrl,
      )..manga.value = manga;
      final result = await widget.ref.read(getVideoListProvider(episode: episode).future);
      final videos = result.$1;
      final qualities = <String>{};
      final languages = <String>{};
      for (final video in videos) {
        final quality = _normQuality(video.quality);
        if (quality.trim().isNotEmpty) qualities.add(quality);
        for (final audio in video.audios ?? const []) {
          final label = audio.label?.trim();
          if (label != null && label.isNotEmpty) languages.add(label);
        }
        for (final match in _languageInQuality.allMatches(video.quality)) {
          final label = match.group(0)?.trim();
          if (label != null && label.isNotEmpty) languages.add(label);
        }
      }
      if (qualities.isNotEmpty) {
        row.qualities = qualities.toList()..sort((a, b) => _resRank(a).compareTo(_resRank(b)));
      } else {
        row.qualities = _qualitiesFor(row);
      }
      row.languages = languages.toList()..sort();
      if (_bulkQuality != null) {
        row.quality = _resolveQuality(_qualitiesFor(row), _bulkQuality, _bulkFallback);
      }
      if (_bulkLanguage != null &&
          row.languages.any((language) => language.toLowerCase() == _bulkLanguage!.toLowerCase())) {
        row.language = _bulkLanguage;
      }
    } catch (_) {
      row.qualities = _qualitiesFor(row);
    } finally {
      row.formatsLoading = false;
      if (mounted) setState(() {});
    }
  }

  /// Applies the header selection to every row. A missing resolution is
  /// replaced by the closest one above/below according to [_bulkFallback].
  void _applyBulkQuality(String? target) {
    setState(() {
      _bulkQuality = target;
      for (final row in _rows) {
        row.quality = target == null
            ? null
            : _resolveQuality(_qualitiesFor(row), target, _bulkFallback);
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
        row.language =
            language != null &&
                row.languages.any((candidate) => candidate.toLowerCase() == language.toLowerCase())
            ? language
            : null;
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

  int get _totalSelected => _rows.fold(0, (sum, row) => sum + row.selected.length);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aucune vidéo sélectionnée.')));
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
                  style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800),
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
                    const DropdownMenuItem<String?>(value: null, child: Text('Auto (meilleure)')),
                    for (final q in _formats) DropdownMenuItem<String?>(value: q, child: Text(q)),
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
                    DropdownMenuItem(value: QualityFallback.higher, child: Text('Supérieure')),
                    DropdownMenuItem(value: QualityFallback.lower, child: Text('Inférieure')),
                    DropdownMenuItem(value: QualityFallback.exact, child: Text('Exacte')),
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
                    const DropdownMenuItem<String?>(value: null, child: Text('Toutes les langues')),
                    for (final l in _headerLanguages)
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
                    const DropdownMenuItem<String?>(value: null, child: Text('Toutes')),
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

  Widget _skeletonRow(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48, height: 68, child: AppShimmerBlock(radius: 8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 14,
                  width: double.infinity,
                  child: AppShimmerBlock(radius: 5),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 11,
                  width: MediaQuery.sizeOf(context).width * 0.36,
                  child: const AppShimmerBlock(radius: 5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 70, height: 34, child: AppShimmerBlock(radius: 9)),
        ],
      ),
    );
  }

  Widget _rowCard(_ResolvedVideo row, ColorScheme cs) {
    if (row.loading) return _skeletonRow(cs);
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
          leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: _cover(row.item)),
          title: Text(
            row.item.name?.trim().isNotEmpty == true ? row.item.name!.trim() : 'Vidéo',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            row.loading || row.formatsLoading
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
                child: Text(row.error!, style: const TextStyle(color: mbRed, fontSize: 11.5)),
              )
            else if (isSeries) ...[
              Row(
                children: [
                  Expanded(
                    child: _BulkDropdown<String?>(
                      label: 'Langue',
                      value: row.language,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Toutes')),
                        for (final l in row.languages)
                          DropdownMenuItem<String?>(value: l, child: Text(l)),
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
                        const DropdownMenuItem<String?>(value: null, child: Text('Toutes')),
                        for (final s in row.seasons)
                          DropdownMenuItem<String?>(value: s, child: Text(s)),
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
    final options = <String?>[null, ..._qualitiesFor(row)];
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
          child: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
        ),
      ],
    );
  }

  Widget _footer(ColorScheme cs) {
    final enabled = !_resolvingRows && _totalSelected > 0;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w600),
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
String? _resolveQuality(List<String> available, String target, QualityFallback fallback) {
  if (available.isEmpty) return target;
  final targetRank = _resRank(target);
  final ranked = [for (final q in available) (label: q, rank: _resRank(q))]
    ..sort((a, b) => a.rank.compareTo(b.rank));
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
