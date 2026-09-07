import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_playbutton_card.dart';
import 'package:watchtower/modules/music/widgets/music_track_tile.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

// ─── Search state ─────────────────────────────────────────────────────────────

class _SearchTermNotifier extends Notifier<String> {
  @override
  String build() => '';
}

final musicSearchTermProvider =
    NotifierProvider<_SearchTermNotifier, String>(_SearchTermNotifier.new);

class _SearchTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

final musicSearchTabProvider =
    NotifierProvider<_SearchTabNotifier, int>(_SearchTabNotifier.new);

// ─── Music search tab — mirrors Spotube's SearchPage ─────────────────────────
// Same structure: search field + chip filters (All / Tracks / Albums /
// Artists / Playlists) + results sections.

class MusicSearchTab extends ConsumerStatefulWidget {
  const MusicSearchTab({super.key});

  @override
  ConsumerState<MusicSearchTab> createState() => _MusicSearchTabState();
}

class _MusicSearchTabState extends ConsumerState<MusicSearchTab> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  static const _chips = ['All', 'Tracks', 'Albums', 'Artists', 'Playlists'];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(musicSearchTermProvider));
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String v) {
    ref.read(musicSearchTermProvider.notifier).state = v.trim();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final term = ref.watch(musicSearchTermProvider);
    final chipIdx = ref.watch(musicSearchTabProvider);

    return Column(
      children: [
        // ── Search bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'Artists, songs or podcasts',
              prefixIcon:
                  const Icon(Broken.search_normal_1),
              suffixIcon: AnimatedOpacity(
                opacity: _ctrl.text.isNotEmpty ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  icon: const Icon(Broken.close_circle, iconSize: 18),
                  onPressed: () {
                    _ctrl.clear();
                    ref.read(musicSearchTermProvider.notifier).state = '';
                  },
                ),
              )border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // ── Chip filters ──────────────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            itemCount: _chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final selected = i == chipIdx;
              return GestureDetector(
                onTap: () =>
                    ref.read(musicSearchTabProvider.notifier).state = i,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _chips[i],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : cs.onSurface.withValues(alpha: 0.7),
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // ── Results ───────────────────────────────────────────────────────
        Expanded(
          child: term.isEmpty
              ? _SearchBrowseGrid()
              : _SearchResults(term: term, chipIdx: chipIdx),
        ),
      ],
    );
  }
}

// ─── Browse grid (no search term) ────────────────────────────────────────────

class _SearchBrowseGrid extends StatelessWidget {
  static const _cats = [
    ('Pop', Color(0xFF8D67AB), Broken.note),
    ('Hip-Hop', Color(0xFFBA5D07), Broken.microphone),
    ('Rock', Color(0xFFE8115B), Broken.flash_1),
    ('Electronic', Color(0xFF1E3264), Broken.voice_square),
    ('R&B', Color(0xFF056952), Broken.note_21),
    ('Jazz', Color(0xFF0D73EC), Broken.note),
    ('Classical', Color(0xFF537AA1), Broken.music_playlist),
    ('Podcasts', Color(0xFF8C1932), Broken.microphone_2),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text('Browse categories',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemCount: _cats.length,
            itemBuilder: (_, i) {
              final (name, color, icon) = _cats[i];
              return Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(width: 10),
                    Text(name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Search results (with term) ───────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  final String term;
  final int chipIdx;
  const _SearchResults({required this.term, required this.chipIdx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // In real implementation this would call ref.watch(musicSearchProvider(term))
    // For now show a "connect extension" placeholder.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.element_plus,
                size: 52, color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text('No music extension installed',
                style: tt.titleSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45))),
            const SizedBox(height: 8),
            Text(
              'Install a music metadata extension from the\nMarketplace to search for "$term"',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Broken.shop),
              label: const Text('Open Marketplace'),
            ),
          ],
        ),
      ),
    );
  }
}
