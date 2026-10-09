import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';

/// Shared search chrome used by every search surface (TMDB hub search,
/// extension search, manga search).
///
/// - [SharedSearchHeader] : compact bar — broken back icon on the left, a
///   clean rounded field in the middle with a broken filter icon inside it
///   (no fill highlight), no trailing divider.
/// - [SharedSearchEmptyState] : what is shown before any query — collapsible
///   recent searches, "tout le monde recherche" hot pills, ranked hot tabs.
/// - [SharedSearchShimmerList] : the list-loading skeleton.

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class SharedSearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onFilter;

  /// Number of extension filters currently applied; drives the filter badge.
  final int activeFilterCount;

  const SharedSearchHeader({
    required this.controller,
    required this.onBack,
    required this.onSubmit,
    required this.onChanged,
    required this.onClear,
    this.focusNode,
    this.hint = 'Rechercher…',
    this.onFilter,
    this.activeFilterCount = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final outline = Colors.white.withValues(alpha: .18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            icon: const Icon(Broken.arrow_left, size: 22),
          ),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSubmit,
                    onChanged: onChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    cursorColor: accent,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 4, right: 2),
                        child: Icon(
                          Broken.search_normal,
                          size: 18,
                          color: Colors.white54,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 24,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Effacer',
                              splashRadius: 20,
                              iconSize: 19,
                              visualDensity: VisualDensity.compact,
                              onPressed: onClear,
                              icon: const Icon(
                                Broken.close_circle,
                                color: Colors.white54,
                              ),
                            ),
                          if (onFilter != null)
                            IconButton(
                              tooltip: 'Filtres',
                              splashRadius: 20,
                              iconSize: 19,
                              visualDensity: VisualDensity.compact,
                              onPressed: onFilter,
                              icon: Badge(
                                isLabelVisible: activeFilterCount > 0,
                                label: Text('$activeFilterCount'),
                                backgroundColor: accent,
                                child: Icon(
                                  Broken.filter,
                                  color: activeFilterCount > 0
                                      ? accent
                                      : Colors.white60,
                                ),
                              ),
                            ),
                        ],
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 24,
                      ),
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: accent, width: 1.4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

/// One entry of the ranked hot lists.
class SharedSearchHotItem {
  final String title;
  final String subtitle;
  final String? imageUrl;

  const SharedSearchHotItem({
    required this.title,
    this.subtitle = '',
    this.imageUrl,
  });
}

/// One ranked hot tab (e.g. "Films chauds", "Séries chaudes").
class SharedSearchHotTab {
  final String label;
  final Future<List<SharedSearchHotItem>> items;

  const SharedSearchHotTab({required this.label, required this.items});
}

/// The shared empty illustration: the crying-cat sticker animation, shown
/// before any query and when a search returns nothing.
class SharedSearchEmptyAnimation extends StatelessWidget {
  final String title;
  final String message;
  final double size;

  const SharedSearchEmptyAnimation({
    required this.title,
    required this.message,
    this.size = 168,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size + 44,
              height: size + 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: .07),
              ),
              alignment: Alignment.center,
              child: Lottie.asset(
                'assets/animations/cat_crying.json',
                width: size,
                height: size,
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class SharedSearchEmptyState extends StatefulWidget {
  final List<String> recentSearches;

  /// Kept for API compatibility; the shared empty state no longer renders
  /// hot-search pills or ranked tabs.
  final List<String> hotSearches;
  final List<SharedSearchHotTab> hotTabs;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearRecents;
  final String hintText;

  const SharedSearchEmptyState({
    required this.recentSearches,
    required this.hotSearches,
    required this.hotTabs,
    required this.onSearch,
    required this.onClearRecents,
    this.hintText = 'Que veux-tu regarder ?',
    super.key,
  });

  @override
  State<SharedSearchEmptyState> createState() => _SharedSearchEmptyStateState();
}

class _SharedSearchEmptyStateState extends State<SharedSearchEmptyState> {
  bool _historyOpen = true;

  @override
  Widget build(BuildContext context) {
    final recent = widget.recentSearches;
    return Column(
      children: [
        if (recent.isNotEmpty) _historyHeader(recent),
        Expanded(
          child: SharedSearchEmptyAnimation(
            title: widget.hintText,
            message: 'Tape ta recherche pour commencer.',
          ),
        ),
      ],
    );
  }

  Widget _historyHeader(List<String> recent) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _historyOpen = !_historyOpen),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
            child: Row(
              children: [
                Icon(Broken.clock_1, size: 17, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'Historique',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onClearRecents,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.white54,
                  ),
                  child: const Text('Effacer'),
                ),
                Icon(
                  _historyOpen ? Broken.arrow_up_1 : Broken.arrow_down_1,
                  size: 18,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
        if (_historyOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _HotChips(
              labels: recent,
              onSearch: widget.onSearch,
              outlined: false,
            ),
          ),
      ],
    );
  }
}

class _HotChips extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<String> onSearch;
  final bool outlined;

  const _HotChips({
    required this.labels,
    required this.onSearch,
    required this.outlined,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels.take(12))
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSearch(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: outlined
                    ? Colors.white.withValues(alpha: .06)
                    : cs.primary.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(18),
                border: outlined
                    ? Border.all(color: Colors.white12)
                    : Border.all(color: cs.primary.withValues(alpha: .25)),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: outlined
                      ? Colors.white.withValues(alpha: .87)
                      : cs.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SharedSearchShimmerList extends StatelessWidget {
  final int rows;

  const SharedSearchShimmerList({this.rows = 8, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rows,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) =>
          SizedBox(height: 76, child: AppShimmerBlock(radius: 14)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent-search storage helpers
// ─────────────────────────────────────────────────────────────────────────────

Future<List<String>> loadRecentSearches(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key) ?? const <String>[];
}

Future<void> saveRecentSearch(String key, String query) async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getStringList(key) ?? const <String>[];
  final next = <String>[
    query,
    ...current.where((v) => v.toLowerCase() != query.toLowerCase()),
  ].take(12).toList(growable: false);
  await prefs.setStringList(key, next);
}

Future<void> removeRecentSearch(String key, String query) async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getStringList(key) ?? const <String>[];
  await prefs.setStringList(key, current.where((v) => v != query).toList());
}

Future<void> clearRecentSearches(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}
