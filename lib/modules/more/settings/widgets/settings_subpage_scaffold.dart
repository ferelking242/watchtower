import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_search_index.dart';

/// Collapsing header shared by every settings page.
///
/// Rest state (scroll offset 0) has no bar at all: the only chrome is the back
/// chevron floating top-left, the page title sits on the page, and the search
/// field sits under it. Once the user scrolls, the title slides into a pinned
/// bar and a search icon appears on its right; tapping that icon grows a search
/// field leftwards while the back chevron stays put.
///
/// This mirrors Mihon's settings sub-pages, where the header is progressive
/// rather than always-on.
class SettingsSubpageScaffold extends StatefulWidget {
  const SettingsSubpageScaffold({
    super.key,
    required this.title,
    this.slivers = const [],
    this.body,
    this.trailing,
    this.bottom,
    this.floatingActionButton,
    this.leading,
    this.showSearch = true,
    this.searchHint = 'Rechercher dans les paramètres…',
    this.onSearchChanged,
    this.expandedHeight,
  }) : assert(
         slivers.length > 0 || body != null,
         'Provide either slivers or a body',
       );

  final String title;
  final List<Widget> slivers;

  /// Alternative to [slivers] for screens that bring their own scrollable
  /// (for example a `ReorderableListView`). Rendered as a filling sliver so the
  /// collapsing header still works.
  final Widget? body;
  final Widget? trailing;

  /// Pinned below the collapsed header, for pages that need tabs.
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;

  /// Overrides the default back chevron.
  final Widget? leading;

  /// Set to false on pages where a free-text filter makes no sense.
  final bool showSearch;
  final String searchHint;

  /// When provided, the on-page field is a local filter instead of the global
  /// cross-page search. The page owns the filtering.
  final ValueChanged<String>? onSearchChanged;

  /// Kept for source compatibility with callers that sized the old header.
  /// Ignored: the rest-state header is sized by its content.
  final double? expandedHeight;

  @override
  State<SettingsSubpageScaffold> createState() =>
      _SettingsSubpageScaffoldState();
}

class _SettingsSubpageScaffoldState extends State<SettingsSubpageScaffold> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _pageSearch = TextEditingController();
  final TextEditingController _headerSearch = TextEditingController();
  final FocusNode _headerFocus = FocusNode();

  bool _collapsed = false;
  bool _headerSearchActive = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _pageSearch.dispose();
    _headerSearch.dispose();
    _headerFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed =
        _scrollController.hasClients && _scrollController.offset > 16;
    if (collapsed != _collapsed && mounted) {
      setState(() => _collapsed = collapsed);
    }
  }

  void _openHeaderSearch() {
    setState(() => _headerSearchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _headerFocus.requestFocus();
    });
  }

  void _closeHeaderSearch() {
    _headerSearch.clear();
    setState(() => _headerSearchActive = false);
  }

  bool get _usesLocalFilter => widget.onSearchChanged != null;

  void _onPageQuery(String value) {
    widget.onSearchChanged?.call(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final globalQuery = _usesLocalFilter ? '' : _pageSearch.text.trim();

    return Scaffold(
      floatingActionButton: widget.floatingActionButton,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
            _onScroll();
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context, cs),
            if (_headerSearchActive && !_usesLocalFilter)
              SliverToBoxAdapter(
                child: _GlobalSearchResults(
                  query: _headerSearch.text,
                  onDismiss: _closeHeaderSearch,
                ),
              )
            else if (globalQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: _GlobalSearchResults(
                  query: globalQuery,
                  onDismiss: () {
                    _pageSearch.clear();
                    setState(() {});
                  },
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _pageHeader(context, cs)),
              if (widget.body != null)
                SliverFillRemaining(hasScrollBody: true, child: widget.body!)
              else
                ...widget.slivers,
            ],
          ],
        ),
      ),
    );
  }

  // ── Rest-state page header: title + search field ───────────────────────────

  Widget _pageHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (widget.showSearch) ...[
            const SizedBox(height: 14),
            _searchField(
              controller: _pageSearch,
              hint: widget.searchHint,
              onChanged: _onPageQuery,
              onClear: () {
                _pageSearch.clear();
                _onPageQuery('');
              },
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    bool autofocus = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: const Icon(Broken.search_normal, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Broken.close_circle, size: 20),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── Progressive app bar ────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, ColorScheme cs) {
    final showBar = _collapsed || _headerSearchActive;

    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: kToolbarHeight,
      backgroundColor: showBar ? cs.surface : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      bottom: widget.bottom,
      automaticallyImplyLeading: false,
      leading:
          widget.leading ??
          IconButton(
            icon: const Icon(Broken.arrow_left_2),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
          ),
      titleSpacing: 0,
      title: _headerSearchActive
          ? _searchField(
              controller: _headerSearch,
              hint: 'Rechercher dans les paramètres…',
              onChanged: (_) => setState(() {}),
              onClear: () {
                _headerSearch.clear();
                setState(() {});
              },
              autofocus: true,
            )
          : AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      actions: [
        if (!_headerSearchActive && widget.showSearch)
          AnimatedOpacity(
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_collapsed,
              child: IconButton(
                icon: const Icon(Broken.search_normal),
                tooltip: 'Rechercher',
                onPressed: _openHeaderSearch,
              ),
            ),
          ),
        if (_headerSearchActive)
          IconButton(
            icon: const Icon(Broken.close_circle),
            tooltip: 'Fermer la recherche',
            onPressed: _closeHeaderSearch,
          ),
        ?widget.trailing,
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Global results shown while the settings search is active. Spans every
/// settings page, so "général" finds entries in Général and "don't kill" finds
/// the Advanced entry even from another page.
class _GlobalSearchResults extends StatelessWidget {
  const _GlobalSearchResults({required this.query, required this.onDismiss});

  final String query;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = query.trim();
    if (q.isEmpty) return const SizedBox.shrink();
    final entries = searchSettings(q);

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        child: Column(
          children: [
            Icon(
              Broken.search_normal,
              size: 42,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun résultat pour « $q »',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Résultats dans les paramètres',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: cs.primary,
            ),
          ),
        ),
        ...entries.map(
          (e) => ListTile(
            dense: true,
            leading: Icon(Broken.setting_5, color: cs.primary, size: 20),
            title: Text(e.title),
            subtitle: Text(
              e.page,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            onTap: () {
              onDismiss();
              context.push(e.route);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
