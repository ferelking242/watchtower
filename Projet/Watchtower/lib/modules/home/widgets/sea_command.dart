import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AniList search provider (scoped to Sea Command palette)
// ─────────────────────────────────────────────────────────────────────────────

final seaCommandSearchProvider =
    FutureProvider.autoDispose.family<List<AnilistMedia>, String>(
  (ref, query) async {
    if (query.trim().length < 2) return [];
    const endpoint = 'https://graphql.anilist.co';
    const gql = r'''
query ($q: String) {
  Page(perPage: 12) {
    media(search: $q, sort: POPULARITY_DESC) {
      id type format averageScore episodes chapters
      title { romaji english }
      coverImage { large extraLarge }
    }
  }
}''';
    final res = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': gql, 'variables': {'q': query}}),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['data']?['Page']?['media'] as List?) ?? [];
    return list
        .map((e) => AnilistMedia.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Navigation quick actions shown when query is empty
// ─────────────────────────────────────────────────────────────────────────────

class _NavAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final bool push;
  const _NavAction(this.label, this.icon, this.color, this.route,
      {this.push = false});
}

const _kNavActions = [
  _NavAction('Accueil',       Icons.home_rounded,                  Color(0xFF6C5CE7), '/WatchtowerHome'),
  _NavAction('Bibliothèque',  Icons.collections_bookmark_rounded,  Color(0xFF00B894), '/Library'),
  _NavAction('Parcourir',     Icons.explore_rounded,               Color(0xFF0984E3), '/browse'),
  _NavAction('Historique',    Icons.history_rounded,               Color(0xFFE17055), '/history'),
  _NavAction('Mises à jour',  Icons.new_releases_rounded,          Color(0xFFE84393), '/updates'),
  _NavAction('Suivi',         Icons.account_tree_rounded,          Color(0xFF55EFC4), '/trackerLibrary'),
  _NavAction('Paramètres',    Icons.settings_rounded,              Color(0xFF636E72), '/more'),
  _NavAction('Rechercher',    Icons.search_rounded,                Color(0xFFF39C12), '/globalSearch', push: true),
];

// ─────────────────────────────────────────────────────────────────────────────
// Public API — call this from anywhere to open the palette
// ─────────────────────────────────────────────────────────────────────────────

void showSeaCommand(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Sea Command',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -0.04), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, __) => const _SeaCommandOverlay(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main overlay
// ─────────────────────────────────────────────────────────────────────────────

class _SeaCommandOverlay extends ConsumerStatefulWidget {
  const _SeaCommandOverlay();

  @override
  ConsumerState<_SeaCommandOverlay> createState() => _SeaCommandOverlayState();
}

class _SeaCommandOverlayState extends ConsumerState<_SeaCommandOverlay> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v);
    });
  }

  void _navigate(_NavAction a) {
    Navigator.of(context).pop();
    if (a.push) {
      context.push(a.route);
    } else {
      context.go(a.route);
    }
  }

  void _openMedia(AnilistMedia m) {
    Navigator.of(context).pop();
    context.push('/anilistDetail', extra: m);
  }

  void _openFullSearch() {
    final q = _query.trim();
    if (q.isEmpty) return;
    Navigator.of(context).pop();
    context.push('/globalSearch', extra: (q, q));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQuery = _query.trim().length >= 2;
    final results = hasQuery
        ? ref.watch(seaCommandSearchProvider(_query.trim()))
        : const AsyncValue<List<AnilistMedia>>.data([]);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) {
        if (e is KeyDownEvent &&
            e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Align(
        alignment: const Alignment(0, -0.22),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F1020).withValues(alpha: 0.93)
                          : cs.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.30),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: 48,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Search field ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  size: 22, color: cs.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  focusNode: _focus,
                                  onChanged: _onChanged,
                                  onSubmitted: (_) => _openFullSearch(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Rechercher anime, manga, titre…',
                                    hintStyle: TextStyle(
                                      color: cs.onSurface
                                          .withValues(alpha: 0.38),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  cursorColor: cs.primary,
                                ),
                              ),
                              if (_ctrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _ctrl.clear();
                                    setState(() => _query = '');
                                  },
                                  child: Icon(Icons.close_rounded,
                                      size: 18,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.40)),
                                ),
                            ],
                          ),
                        ),

                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: cs.outlineVariant.withValues(alpha: 0.25),
                        ),

                        // ── Body ─────────────────────────────────────────
                        if (!hasQuery)
                          _QuickActionsSection(
                              actions: _kNavActions,
                              onTap: _navigate,
                              cs: cs)
                        else
                          results.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            ),
                            error: (e, _) => Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('Erreur de recherche',
                                  style: TextStyle(color: cs.error)),
                            ),
                            data: (items) => items.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Aucun résultat pour "$_query"',
                                      style: TextStyle(
                                          color: cs.onSurface
                                              .withValues(alpha: 0.55)),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxHeight: 390),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      shrinkWrap: true,
                                      itemCount: items.length,
                                      itemBuilder: (_, i) =>
                                          _ResultTile(
                                        media: items[i],
                                        onTap: () => _openMedia(items[i]),
                                        cs: cs,
                                      ),
                                    ),
                                  ),
                          ),

                        // ── Footer hint ──────────────────────────────────
                        _CommandFooter(
                            cs: cs,
                            hasQuery: hasQuery,
                            onSearch: _openFullSearch),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Quick action chips
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final List<_NavAction> actions;
  final void Function(_NavAction) onTap;
  final ColorScheme cs;

  const _QuickActionsSection(
      {required this.actions, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NAVIGATION RAPIDE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.38),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                actions.map((a) => _ActionChip(a: a, onTap: () => onTap(a), cs: cs)).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final _NavAction a;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _ActionChip({required this.a, required this.onTap, required this.cs});

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hov
                ? widget.a.color.withValues(alpha: 0.18)
                : widget.cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hov
                  ? widget.a.color.withValues(alpha: 0.38)
                  : widget.cs.outlineVariant.withValues(alpha: 0.20),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.a.icon, size: 14,
                  color: _hov
                      ? widget.a.color
                      : widget.cs.onSurface.withValues(alpha: 0.62)),
              const SizedBox(width: 7),
              Text(
                widget.a.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _hov
                      ? widget.a.color
                      : widget.cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result tile
// ─────────────────────────────────────────────────────────────────────────────

class _ResultTile extends StatefulWidget {
  final AnilistMedia media;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ResultTile(
      {required this.media, required this.onTap, required this.cs});

  @override
  State<_ResultTile> createState() => _ResultTileState();
}

class _ResultTileState extends State<_ResultTile> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hov
                ? widget.cs.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: m.bestCover != null
                    ? ExtendedImage.network(
                        m.bestCover!,
                        width: 44,
                        height: 62,
                        fit: BoxFit.cover,
                        cache: true,
                      )
                    : Container(
                        width: 44,
                        height: 62,
                        decoration: BoxDecoration(
                          color: widget.cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
              ),
              const SizedBox(width: 13),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: widget.cs.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (m.format != null) ...[
                          _Pill(
                              m.format!.replaceAll('_', ' '),
                              widget.cs.primary),
                          const SizedBox(width: 6),
                        ],
                        if (m.averageScore != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 11, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            (m.averageScore! / 10).toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.cs.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                        if (m.episodes != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${m.episodes} ep.',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.cs.onSurface
                                  .withValues(alpha: 0.42),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: widget.cs.onSurface
                      .withValues(alpha: _hov ? 0.55 : 0.18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer with keyboard hints
// ─────────────────────────────────────────────────────────────────────────────

class _CommandFooter extends StatelessWidget {
  final ColorScheme cs;
  final bool hasQuery;
  final VoidCallback onSearch;

  const _CommandFooter(
      {required this.cs, required this.hasQuery, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.18))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          _Kbd('↵', cs),
          const SizedBox(width: 5),
          Text('ouvrir', style: _hint(cs)),
          const SizedBox(width: 12),
          _Kbd('Esc', cs),
          const SizedBox(width: 5),
          Text('fermer', style: _hint(cs)),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 11, color: cs.primary.withValues(alpha: 0.70)),
              const SizedBox(width: 4),
              Text(
                'Sea Command',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.primary.withValues(alpha: 0.70),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _hint(ColorScheme cs) => TextStyle(
        fontSize: 11,
        color: cs.onSurface.withValues(alpha: 0.38),
      );
}

class _Kbd extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _Kbd(this.text, this.cs);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.22)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.50),
          ),
        ),
      );
}
