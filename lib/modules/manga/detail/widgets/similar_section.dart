import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/catalog_filter_sheet.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/overlay_filter_menu.dart';
import 'package:watchtower/services/recommendation.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

/// Inline "Similar" tab for the manga detail page.
///
/// The recommendations used to live behind a "Voir" button that pushed a
/// separate screen. They are rendered here instead, directly under the tab,
/// with the shared glass filter (local search + display density) and a
/// three-dots menu built from [AdaptiveOverlayMenu] — the same components the
/// library, the catalogue and the extension search use.
class SimilarSection extends ConsumerStatefulWidget {
  final String name;
  final ItemType itemType;
  final AlgorithmWeights weights;

  const SimilarSection({
    super.key,
    required this.name,
    required this.itemType,
    required this.weights,
  });

  @override
  ConsumerState<SimilarSection> createState() => _SimilarSectionState();
}

class _SimilarSectionState extends ConsumerState<SimilarSection> {
  List<RecommendationResult>? _data;
  bool _loading = true;
  String? _error;

  CatalogLayout _layout = CatalogLayout.grid;
  int _columns = 0;
  String _query = '';
  String _sort = 'score';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await getRecommendations(
        widget.name,
        widget.itemType,
        widget.weights,
      );
      if (!mounted) return;
      setState(() {
        _data = data ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _titleOf(RecommendationResult r) =>
      r.titleEnglish ?? r.titleRomaji ?? r.titleNative ?? '';

  List<RecommendationResult> get _visible {
    final all = List<RecommendationResult>.from(_data ?? const []);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((r) => _titleOf(r).toLowerCase().contains(q)).toList();
    if (_sort == 'score') {
      filtered.sort((a, b) => b.score.compareTo(a.score));
    } else {
      filtered.sort((a, b) => _titleOf(a).compareTo(_titleOf(b)));
    }
    return filtered;
  }

  void _open(RecommendationResult r) {
    final title = _titleOf(r);
    if (title.isEmpty) return;
    context.push('/globalSearch', extra: (title, widget.itemType));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              Icon(Broken.star, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Similar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              if (!_loading && _error == null) ...[
                const SizedBox(width: 8),
                Text(
                  '${results.length}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              AdaptiveOverlayMenuButton(
                trigger: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Broken.filter,
                    size: 20,
                    color: _query.trim().isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                ),
                contentBuilder: (close) => ExtensionFilterOverlay(
                  filterList: const [],
                  onChanged: (_) {},
                  close: close,
                  searchValue: _query,
                  onSearchChanged: (value) {
                    if (mounted) setState(() => _query = value);
                  },
                  layout: _layout,
                  columns: _columns,
                  onLayoutChanged: (value) =>
                      setState(() => _layout = value),
                  onColumnsChanged: (value) =>
                      setState(() => _columns = value),
                ),
              ),
              AdaptiveOverlayMenu<String>(
                icon: Icon(
                  Broken.more_2,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                menuWidth: 220,
                initialValue: _sort,
                onSelected: (value) {
                  switch (value) {
                    case 'refresh':
                      _load();
                    case 'sort_score':
                      setState(() => _sort = 'score');
                    case 'sort_title':
                      setState(() => _sort = 'title');
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Broken.refresh, size: 18),
                        SizedBox(width: 10),
                        Text('Actualiser'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'sort_score',
                    child: Row(
                      children: [
                        Icon(Broken.chart_2, size: 18),
                        SizedBox(width: 10),
                        Text('Meilleures correspondances'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sort_title',
                    child: Row(
                      children: [
                        Icon(Broken.sort, size: 18),
                        SizedBox(width: 10),
                        Text('Titre (A-Z)'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null)
          _emptyState(
            icon: Broken.warning_2,
            message: 'Impossible de charger les titres similaires.',
            action: FilledButton.tonal(
              onPressed: _load,
              child: const Text('Réessayer'),
            ),
          )
        else if (results.isEmpty)
          _emptyState(
            icon: Broken.star,
            message: 'Aucun titre similaire trouvé.',
          )
        else
          _buildGrid(results),
      ],
    );
  }

  Widget _buildGrid(List<RecommendationResult> results) {
    final padding = EdgeInsets.fromLTRB(
      AppUI.pagePadding(context),
      12,
      AppUI.pagePadding(context),
      24,
    );
    if (_layout == CatalogLayout.list) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: results.length,
        itemBuilder: (context, index) => _listRow(results[index]),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: catalogDisplayColumns(
          deviceColumns: AppUI.mediaGridColumns(context),
          layout: _layout,
          columns: _columns,
        ),
        childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) => _card(results[index]),
    );
  }

  Widget _card(RecommendationResult r) {
    final item = ContentItem(
      key: 'reco-${r.id}',
      title: _titleOf(r).isEmpty ? 'Sans titre' : _titleOf(r),
      posterUrl: r.imgURLs.isNotEmpty ? r.imgURLs.first : null,
      description: r.description,
      rating: r.score > 0 ? r.score / 20 : null,
      badge: r.genres.isNotEmpty ? r.genres.first : null,
    );
    return PosterCard(
      item: item,
      width: double.infinity,
      compact: _layout == CatalogLayout.compact,
      titleOnCover: catalogLayoutTitleOnCover(_layout),
      showTitle: catalogLayoutShowTitle(_layout),
      onTap: () => _open(r),
    );
  }

  Widget _listRow(RecommendationResult r) {
    final scheme = Theme.of(context).colorScheme;
    final cover = r.imgURLs.isNotEmpty ? r.imgURLs.first : null;
    return InkWell(
      onTap: () => _open(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 66,
                child: cover == null
                    ? Container(color: scheme.surfaceContainerHighest)
                    : Image.network(cover, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleOf(r),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (r.score > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${r.score}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Broken.arrow_right_3, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 34, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }
}
