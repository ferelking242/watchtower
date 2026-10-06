import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';

/// Shared search chrome used by every search surface (TMDB hub search,
/// extension search, manga search).
///
/// - [SharedSearchHeader] : MovieBox-style compact bar — back button on the
///   left, tight rounded field in the middle, live mic dictation on the right.
/// - [SharedSearchEmptyState] : what is shown before any query — recent
///   searches, "tout le monde recherche" hot pills, then ranked hot tabs.
/// - [SharedSearchShimmerList] : the list-loading skeleton.

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class SharedSearchHeader extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool listening;

  /// Notified when the internal dictation starts/stops so parents can react.
  final ValueChanged<bool>? onListeningChanged;

  const SharedSearchHeader({
    required this.controller,
    required this.onBack,
    required this.onSubmit,
    required this.onChanged,
    required this.onClear,
    this.focusNode,
    this.hint = 'Rechercher…',
    this.listening = false,
    this.onListeningChanged,
    super.key,
  });

  @override
  State<SharedSearchHeader> createState() => _SharedSearchHeaderState();
}

class _SharedSearchHeaderState extends State<SharedSearchHeader> {
  SpeechToText? _speech;
  bool _available = false;

  void _setListening(bool value) {
    widget.onListeningChanged?.call(value);
  }

  Future<void> _toggleMic() async {
    if (widget.listening) {
      await _speech?.stop();
      _setListening(false);
      if (mounted) setState(() {});
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      _speech ??= SpeechToText();
      _available = await _speech!.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() {});
          }
        },
      );
      if (!_available) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Micro indisponible sur cet appareil'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      await _speech!.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isEmpty) return;
          widget.controller
            ..text = words
            ..selection = TextSelection.collapsed(offset: words.length);
          widget.onChanged(words);
          if (result.finalResult) {
            widget.onSubmit(words);
            _speech?.stop();
            _setListening(false);
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
        listenFor: const Duration(seconds: 10),
        localeId: 'fr_FR',
      );
      _setListening(true);
      if (mounted) setState(() {});
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Dictée vocale indisponible'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _speech?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final listening = widget.listening || (_available && _speech?.isListening == true);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 8, 10),
      child: Row(
        children: [
          // Back
          IconButton(
            tooltip: 'Retour',
            onPressed: widget.onBack,
            icon: const Icon(Broken.arrow_left, size: 22),
          ),
          // Compact field
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: widget.onSubmit,
                onChanged: widget.onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                cursorColor: accent,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(
                    Broken.search_normal,
                    size: 18,
                    color: Colors.white54,
                  ),
                  suffixIcon: widget.controller.text.isEmpty
                      ? null
                      : GestureDetector(
                          onTap: widget.onClear,
                          child: Icon(
                            Broken.close_circle,
                            size: 19,
                            color: Colors.white54,
                          ),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .05),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accent.withValues(alpha: .55),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accent.withValues(alpha: .55),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          // Mic — live dictation
          _MicButton(
            listening: listening,
            accent: accent,
            onPressed: _toggleMic,
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final Color accent;
  final VoidCallback onPressed;

  const _MicButton({
    required this.listening,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Recherche vocale',
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: listening
            ? Icon(Icons.mic_rounded, key: const ValueKey('on'), color: accent)
            : Icon(
                Icons.mic_none_rounded,
                key: const ValueKey('off'),
                color: Colors.white60,
              ),
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

class SharedSearchEmptyState extends StatelessWidget {
  final List<String> recentSearches;
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
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big friendly empty title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Broken.search_normal, size: 42, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  hintText,
                  style: tt.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tape ou dicte ta recherche pour commencer.',
                  style: tt.bodyMedium?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          // Recent searches
          if (recentSearches.isNotEmpty) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Text(
                    'Récent',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onClearRecents,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Effacer'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HotChips(
                labels: recentSearches,
                onSearch: onSearch,
                outlined: false,
              ),
            ),
          ],
          // Hot searches — what everyone looks for
          if (hotSearches.isNotEmpty) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 19,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Tout le monde recherche',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HotChips(
                labels: hotSearches,
                onSearch: onSearch,
                outlined: true,
              ),
            ),
          ],
          // Ranked hot tabs
          if (hotTabs.isNotEmpty) ...[
            const SizedBox(height: 26),
            SizedBox(
              height: 500,
              child: DefaultTabController(
                length: hotTabs.length,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorColor: cs.primary,
                      labelColor: cs.primary,
                      unselectedLabelColor: Colors.white54,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tabs: [
                        for (final tab in hotTabs) Tab(text: tab.label),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final tab in hotTabs)
                            _RankedHotList(items: tab.items, onSearch: onSearch),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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

class _RankedHotList extends StatelessWidget {
  final Future<List<SharedSearchHotItem>> items;
  final ValueChanged<String> onSearch;

  const _RankedHotList({required this.items, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SharedSearchHotItem>>(
      future: items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SharedSearchShimmerList();
        }
        final list = snapshot.data ?? const <SharedSearchHotItem>[];
        if (list.isEmpty) {
          return Center(
            child: Text(
              'Aucune donnée',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final item = list[i];
            final imageUrl = item.imageUrl?.trim();
            return InkWell(
              onTap: () => onSearch(item.title),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: i < 3
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl == null || imageUrl.isEmpty
                          ? Container(
                              width: 44,
                              height: 62,
                              color: Colors.white10,
                              child: const Icon(
                                Broken.image,
                                color: Colors.white24,
                                size: 20,
                              ),
                            )
                          : Image.network(
                              imageUrl,
                              width: 44,
                              height: 62,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44,
                                height: 62,
                                color: Colors.white10,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .55),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.white24,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class SharedSearchShimmerList extends StatelessWidget {
  final int rows;

  const SharedSearchShimmerList({this.rows = 8, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rows,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => SizedBox(
        height: 76,
        child: AppShimmerBlock(radius: 14),
      ),
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
  await prefs.setStringList(
    key,
    current.where((v) => v != query).toList(),
  );
}

Future<void> clearRecentSearches(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}
