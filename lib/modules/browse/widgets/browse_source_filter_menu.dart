import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

enum BrowseNsfwFilter { all, sfw, nsfw }

enum BrowseSourceTag {
  cloudflare,
  account,
  drm,
  aggregator,
  comments,
  torrent,
  update,
  javascript,
  dart,
}

extension BrowseSourceTagLabel on BrowseSourceTag {
  String label(AppLocalizations l10n) => switch (this) {
        BrowseSourceTag.cloudflare => l10n.browse_tag_cloudflare,
        BrowseSourceTag.account => l10n.browse_tag_account,
        BrowseSourceTag.drm => l10n.browse_tag_drm,
        BrowseSourceTag.aggregator => l10n.browse_tag_aggregator,
        BrowseSourceTag.comments => l10n.browse_tag_comments,
        BrowseSourceTag.torrent => l10n.browse_tag_torrent,
        BrowseSourceTag.update => l10n.browse_tag_update,
        BrowseSourceTag.javascript => l10n.browse_tag_javascript,
        BrowseSourceTag.dart => l10n.browse_tag_dart,
      };

  IconData get icon => switch (this) {
        BrowseSourceTag.cloudflare => Icons.cloud_outlined,
        BrowseSourceTag.account => Icons.person_outline_rounded,
        BrowseSourceTag.drm => Icons.lock_outline_rounded,
        BrowseSourceTag.aggregator => Icons.hub_outlined,
        BrowseSourceTag.comments => Icons.chat_bubble_outline_rounded,
        BrowseSourceTag.torrent => Icons.download_outlined,
        BrowseSourceTag.update => Icons.system_update_alt_rounded,
        BrowseSourceTag.javascript => Icons.code_rounded,
        BrowseSourceTag.dart => Icons.flutter_dash,
      };
}

class BrowseSourceFilters {
  final bool onlyActive;
  final BrowseNsfwFilter nsfw;
  final String? language;
  final Set<BrowseSourceTag> tags;

  const BrowseSourceFilters({
    this.onlyActive = false,
    this.nsfw = BrowseNsfwFilter.all,
    this.language,
    this.tags = const {},
  });

  bool get hasAny =>
      onlyActive ||
      nsfw != BrowseNsfwFilter.all ||
      language != null ||
      tags.isNotEmpty;

  BrowseSourceFilters copyWith({
    bool? onlyActive,
    BrowseNsfwFilter? nsfw,
    String? language,
    bool clearLanguage = false,
    Set<BrowseSourceTag>? tags,
  }) {
    return BrowseSourceFilters(
      onlyActive: onlyActive ?? this.onlyActive,
      nsfw: nsfw ?? this.nsfw,
      language: clearLanguage ? null : language ?? this.language,
      tags: tags ?? this.tags,
    );
  }

  BrowseSourceFilters toggleTag(BrowseSourceTag tag) {
    final next = {...tags};
    if (!next.add(tag)) next.remove(tag);
    return copyWith(tags: next);
  }

  bool matches(Source source, String query) {
    if (source.isAdded != true) return false;
    if (onlyActive && source.isActive != true) return false;
    if (language != null && source.lang?.toLowerCase() != language) {
      return false;
    }

    if (nsfw == BrowseNsfwFilter.sfw && source.isNsfw == true) {
      return false;
    }
    if (nsfw == BrowseNsfwFilter.nsfw && source.isNsfw != true) {
      return false;
    }

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      final searchable = [
        source.name,
        source.lang,
        source.baseUrl,
        source.apiUrl,
        source.notes,
        source.typeSource,
        source.sourceCodeUrl,
        source.repo?.name,
        source.repo?.jsonUrl,
        source.repo?.website,
        ...?source.subCategories,
        ...?source.contentSubtype,
      ].whereType<String>().join(' ').toLowerCase();
      if (!searchable.contains(normalizedQuery)) return false;
    }

    return tags.every((tag) => _hasTag(source, tag));
  }

  static bool _hasTag(Source source, BrowseSourceTag tag) {
    switch (tag) {
      case BrowseSourceTag.cloudflare:
        return source.hasCloudflare == true;
      case BrowseSourceTag.account:
        return source.requiresAccount == true;
      case BrowseSourceTag.drm:
        return source.hasDRM == true;
      case BrowseSourceTag.aggregator:
        return source.isAggregator == true;
      case BrowseSourceTag.comments:
        return source.supportsComments == true;
      case BrowseSourceTag.torrent:
        return source.isTorrent;
      case BrowseSourceTag.update:
        return _compareVersions(source.version ?? '', source.versionLast ?? '') < 0;
      case BrowseSourceTag.javascript:
        return source.sourceCodeLanguage == SourceCodeLanguage.javascript;
      case BrowseSourceTag.dart:
        return source.sourceCodeLanguage == SourceCodeLanguage.dart;
    }
  }

  static int _compareVersions(String a, String b) {
    List<int> parse(String value) => value
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .take(4)
        .toList();

    final left = parse(a);
    final right = parse(b);
    for (var i = 0; i < 4; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }
}

class BrowseSourceFilterMenu extends StatefulWidget {
  final BrowseSourceFilters filters;
  final List<Source> availableSources;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<BrowseSourceFilters> onChanged;

  const BrowseSourceFilterMenu({
    super.key,
    required this.filters,
    required this.availableSources,
    this.searchQuery = '',
    this.onSearchChanged,
    required this.onChanged,
  });

  @override
  State<BrowseSourceFilterMenu> createState() => _BrowseSourceFilterMenuState();
}

enum _BrowseFilterLevel { root, nsfw, languages, tags }

class _BrowseSourceFilterMenuState extends State<BrowseSourceFilterMenu> {
  late BrowseSourceFilters _filters = widget.filters;
  _BrowseFilterLevel _level = _BrowseFilterLevel.root;
  late final TextEditingController _searchController =
      TextEditingController(text: widget.searchQuery);

  @override
  void didUpdateWidget(covariant BrowseSourceFilterMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
    if (oldWidget.filters != widget.filters) {
      _filters = widget.filters;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(BrowseSourceFilters filters) {
    setState(() => _filters = filters);
    widget.onChanged(filters);
  }

  Widget _backHeader(String title) {
    return InkWell(
      onTap: () => setState(() => _level = _BrowseFilterLevel.root),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 6),
        child: Row(
          children: [
            const Icon(Broken.arrow_left_2, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _languages {
    return widget.availableSources
        .where((source) => source.isAdded == true)
        .map((source) => source.lang?.toLowerCase() ?? '')
        .where((language) => language.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Widget _buildRoot() {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveOverlaySection(title: l10n.browse_filter_installed),
        AdaptiveOverlayItem(
          icon: Icons.check_circle_outline_rounded,
          label: l10n.browse_filter_active_only,
          selected: _filters.onlyActive,
          onTap: () => _update(
            _filters.copyWith(onlyActive: !_filters.onlyActive),
          ),
        ),
        AdaptiveOverlayItem(
          icon: Icons.visibility_off_outlined,
          label: l10n.browse_filter_content_nsfw,
          trailing: const Icon(Broken.arrow_right_3, size: 14),
          onTap: () => setState(() => _level = _BrowseFilterLevel.nsfw),
        ),
        AdaptiveOverlayItem(
          icon: Icons.language_rounded,
          label: _filters.language == null
              ? l10n.browse_filter_all_languages
              : l10n.browse_filter_language_prefix(
                  _filters.language!.toUpperCase()),
          trailing: const Icon(Broken.arrow_right_3, size: 14),
          onTap: () => setState(() => _level = _BrowseFilterLevel.languages),
        ),
        AdaptiveOverlayItem(
          icon: Broken.tag,
          label: _filters.tags.isEmpty
              ? l10n.browse_filter_tags
              : l10n.browse_filter_tags_count(_filters.tags.length),
          trailing: const Icon(Broken.arrow_right_3, size: 14),
          onTap: () => setState(() => _level = _BrowseFilterLevel.tags),
        ),
        if (_filters.hasAny) ...[
          const AdaptiveOverlayDivider(),
          AdaptiveOverlayItem(
            icon: Broken.refresh_left_square,
            label: l10n.browse_reset_filters,
            onTap: () => _update(const BrowseSourceFilters()),
          ),
        ],
      ],
    );
  }

  Widget _buildNsfw() {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _backHeader(l10n.browse_filter_content_nsfw),
        AdaptiveOverlayItem(
          label: l10n.browse_all_content,
          selected: _filters.nsfw == BrowseNsfwFilter.all,
          onTap: () {
            _update(_filters.copyWith(nsfw: BrowseNsfwFilter.all));
            setState(() => _level = _BrowseFilterLevel.root);
          },
        ),
        AdaptiveOverlayItem(
          label: l10n.browse_sfw_only,
          selected: _filters.nsfw == BrowseNsfwFilter.sfw,
          onTap: () {
            _update(_filters.copyWith(nsfw: BrowseNsfwFilter.sfw));
            setState(() => _level = _BrowseFilterLevel.root);
          },
        ),
        AdaptiveOverlayItem(
          label: l10n.browse_nsfw_only,
          selected: _filters.nsfw == BrowseNsfwFilter.nsfw,
          onTap: () {
            _update(_filters.copyWith(nsfw: BrowseNsfwFilter.nsfw));
            setState(() => _level = _BrowseFilterLevel.root);
          },
        ),
      ],
    );
  }

  Widget _buildLanguages() {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _backHeader(l10n.language),
        AdaptiveOverlayItem(
          label: l10n.browse_filter_all_languages,
          selected: _filters.language == null,
          onTap: () {
            _update(_filters.copyWith(clearLanguage: true));
            setState(() => _level = _BrowseFilterLevel.root);
          },
        ),
        for (final language in _languages)
          AdaptiveOverlayItem(
            label: language.toUpperCase(),
            selected: _filters.language == language,
            onTap: () {
              _update(_filters.copyWith(language: language));
              setState(() => _level = _BrowseFilterLevel.root);
            },
          ),
      ],
    );
  }

  Widget _buildTags() {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _backHeader(l10n.browse_filter_tags),
        for (final tag in BrowseSourceTag.values)
          AdaptiveOverlayItem(
            icon: tag.icon,
            label: tag.label(l10n),
            selected: _filters.tags.contains(tag),
            onTap: () => _update(_filters.toggleTag(tag)),
          ),
        const AdaptiveOverlayDivider(),
        AdaptiveOverlayItem(
          label: l10n.browse_filter_done,
          icon: Broken.tick_circle,
          onTap: () => setState(() => _level = _BrowseFilterLevel.root),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _searchController,
        onChanged: widget.onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Broken.search_normal, size: 19),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.browse_filter_clear_search,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    widget.onSearchChanged?.call('');
                    setState(() {});
                  },
                ),
          hintText: l10n.browse_filter_search_installed,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchField(),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: switch (_level) {
            _BrowseFilterLevel.root => _buildRoot(),
            _BrowseFilterLevel.nsfw => _buildNsfw(),
            _BrowseFilterLevel.languages => _buildLanguages(),
            _BrowseFilterLevel.tags => _buildTags(),
          },
        ),
      ],
    );
  }
}