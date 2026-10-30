import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';

/// Shared search chrome used by every search surface (TMDB hub search,
/// extension search, manga search).
///
/// - [SharedSearchHeader] : compact bar — a clean "‹" chevron on the left
///   (no filled circle), a rounded field in the middle with the microphone
///   inside it. The filter and the three-dots menus live *outside* the field,
///   composed by the screen so they can reuse the shared overlay component.
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

  /// Starts voice dictation. When null no microphone is shown inside the field.
  final VoidCallback? onMic;

  /// Replaces the default "‹" back button (e.g. to host a badge).
  final Widget? leading;

  /// Foreground colour of the text field. Defaults to the white used by the
  /// dark extension surfaces; a theme-aware caller (the Marketplace) passes its
  /// own so the field stays readable on a light background.
  final Color? foregroundColor;

  /// Hairline colour of the field's border. Same rationale as
  /// [foregroundColor].
  final Color? outlineColor;

  const SharedSearchHeader({
    required this.controller,
    required this.onBack,
    required this.onSubmit,
    required this.onChanged,
    this.focusNode,
    this.hint = 'Rechercher…',
    this.onMic,
    this.leading,
    this.foregroundColor,
    this.outlineColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final foreground = foregroundColor ?? Colors.white;
    final outline = outlineColor ?? Colors.white.withValues(alpha: .18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
      child: Row(
        children: [
          leading ??
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(Broken.arrow_left_2, size: 22),
              ),
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmit,
                onChanged: onChanged,
                style: TextStyle(color: foreground, fontSize: 14.5),
                cursorColor: accent,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: foreground.withValues(alpha: 0.55),
                    fontSize: 13.5,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 2),
                    child: Icon(
                      Broken.search_normal,
                      size: 18,
                      color: foreground.withValues(alpha: 0.65),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 24,
                  ),
                  suffixIcon: onMic == null
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).searchFieldLabel,
                          splashRadius: 20,
                          iconSize: 19,
                          visualDensity: VisualDensity.compact,
                          onPressed: onMic,
                          icon: Icon(
                            Broken.microphone,
                            color: foreground.withValues(alpha: 0.7),
                          ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Back / dictation helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Handles the "‹" chevron and the phone back gesture for a search surface.
///
/// First press clears the field when it holds text; once the field is empty a
/// further press leaves the page. [onExit] must pop the route.
///
/// Returns `true` when the event was consumed (the field was cleared) so the
/// caller can report "handled" to a `PopScope`.
bool handleSearchBack({
  required TextEditingController controller,
  required VoidCallback onClearQuery,
  required VoidCallback onExit,
}) {
  if (controller.text.isNotEmpty) {
    onClearQuery();
    return true;
  }
  onExit();
  return true;
}

/// Starts a one-shot voice dictation and feeds the recognised words to
/// [onResult]. Silently no-ops when speech is unavailable, so the microphone
/// can be offered on every extension regardless of platform support.
Future<void> startVoiceSearch({
  required ValueChanged<String> onResult,
  Duration listenFor = const Duration(seconds: 8),
}) async {
  final speech = SpeechToText();
  final available = await speech.initialize();
  if (!available) return;
  await speech.listen(
    onResult: (result) {
      if (result.recognizedWords.isNotEmpty) {
        onResult(result.recognizedWords);
      }
    },
    listenOptions: SpeechListenOptions(listenFor: listenFor),
  );
  await Future.delayed(listenFor + const Duration(seconds: 1));
  await speech.stop();
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

  const SharedSearchShimmerList({this.rows = 12, super.key});

  @override
  Widget build(BuildContext context) {
    // Squelettes de cartes réelles (même grille que les résultats) au lieu
    // de rectangles génériques.
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        14,
        AppUI.pagePadding(context),
        40,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppUI.mediaGridColumns(context),
        childAspectRatio: AppUI.mediaGridChildAspectRatio(context),
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 16,
      ),
      itemCount: rows,
      itemBuilder: (_, _) => const _ShimmerResultCard(),
    );
  }
}

/// Squelette d'une carte résultat : affiche + deux lignes de titre.
class _ShimmerResultCard extends StatelessWidget {
  const _ShimmerResultCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: AppShimmerBlock(radius: 10)),
        const SizedBox(height: 7),
        const FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.85,
          child: SizedBox(height: 10, child: AppShimmerBlock(radius: 5)),
        ),
        const SizedBox(height: 5),
        const FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.55,
          child: SizedBox(height: 8, child: AppShimmerBlock(radius: 4)),
        ),
      ],
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
