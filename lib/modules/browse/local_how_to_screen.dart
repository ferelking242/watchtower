import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/providers/l10n_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class LocalHowToScreen extends StatelessWidget {
  final ItemType itemType;
  const LocalHowToScreen({required this.itemType, super.key});

  String _typeName(BuildContext context) {
    final l10n = context.l10n;
    return switch (itemType) {
      ItemType.manga => l10n.manga,
      ItemType.anime => l10n.watch,
      ItemType.novel => l10n.novel,
      ItemType.music => l10n.browse_local_type_music,
      ItemType.game => l10n.browse_local_type_game,
      ItemType.plugin => l10n.browse_local_type_plugin,
    };
  }

  String _defaultPath(BuildContext context) {
    final typeName = _typeName(context);
    if (!kIsWeb && Platform.isIOS) {
      // iOS sandbox: Files > On My iPhone > Watchtower > Local/<type>
      return context.l10n.browse_local_default_path(typeName);
    }
    return 'Watchtower/Local/$typeName';
  }

  List<String> get _supportedFormats => switch (itemType) {
        ItemType.manga => ['CBZ', 'ZIP'],
        ItemType.anime => ['MP4', 'MKV', 'AVI', 'MOV', 'FLV', 'MPEG', 'WMV'],
        ItemType.novel => ['EPUB'],
        ItemType.music => ['MP3', 'FLAC', 'AAC', 'OGG', 'WAV', 'M4A', 'OPUS'],
        ItemType.game => ['APK', 'ZIP', 'RAR', '7Z'],
        ItemType.plugin => [],
      };

  String get _folderStructureExample => switch (itemType) {
        ItemType.manga =>
          'Manga/\n'
          '  ├── My Manga Title/\n'
          '  │   ├── Chapter 001.cbz\n'
          '  │   ├── Chapter 002.cbz\n'
          '  │   └── cover.jpg (optionnel)\n'
          '  └── Another Manga/\n'
          '      └── Vol.1 Ch.1.zip',
        ItemType.anime =>
          'Watch/\n'
          '  ├── My Series/\n'
          '  │   ├── Episode 01.mp4\n'
          '  │   ├── Episode 02.mkv\n'
          '  │   └── thumbnail.jpg (optionnel)\n'
          '  └── Movie Title.mp4',
        ItemType.novel =>
          'Novel/\n'
          '  ├── My Novel.epub\n'
          '  └── Series/\n'
          '      ├── Volume 1.epub\n'
          '      └── Volume 2.epub',
        ItemType.music =>
          'Music/\n'
          '  ├── Artist Name/\n'
          '  │   ├── Album Name/\n'
          '  │   │   ├── 01 - Track.mp3\n'
          '  │   │   └── cover.jpg (optionnel)\n'
          '  │   └── Single.flac\n'
          '  └── Playlist/\n'
          '      └── song.ogg',
        ItemType.game =>
          'Game/\n'
          '  ├── Game Title/\n'
          '  │   ├── game.apk\n'
          '  │   └── data.zip\n'
          '  └── Another Game.apk',
        ItemType.plugin =>
          'Plugin/\n'
          '  ├── my-plugin/\n'
          '  │   └── plugin.json\n'
          '  └── another-plugin.json',
      };

  IconData get _typeIcon => switch (itemType) {
        ItemType.manga => Icons.auto_stories_outlined,
        ItemType.anime => Icons.live_tv_outlined,
        ItemType.novel => Icons.menu_book_outlined,
        ItemType.music => Icons.music_note_outlined,
        ItemType.game => Icons.sports_esports_outlined,
        ItemType.plugin => Icons.extension_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(context.l10n.browse_local_how_to_title(_typeName(context))),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          _HeroCard(icon: _typeIcon, typeName: _typeName(context), cs: cs),
          const SizedBox(height: 24),

          // ── Dossier ───────────────────────────────────────────────────────
          _SectionTitle(context.l10n.browse_local_folder),
          const SizedBox(height: 10),
          _InfoCard(
            cs: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PathRow(
                    label: context.l10n.browse_local_default,
                    path: _defaultPath(context)),
                const SizedBox(height: 8),
                _PathRow(
                    label: context.l10n.browse_local_alt,
                    path: !kIsWeb && Platform.isIOS
                        ? context.l10n
                            .browse_local_alt_path(_typeName(context))
                        : 'Download/${_typeName(context)}',
                  ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.browse_local_scan_note,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Formats supportés ─────────────────────────────────────────────
          _SectionTitle(context.l10n.browse_local_formats),
          const SizedBox(height: 10),
          _InfoCard(
            cs: cs,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _supportedFormats
                  .map((f) => _FormatChip(label: f, cs: cs))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),

          // ── Organisation ──────────────────────────────────────────────────
          _SectionTitle(context.l10n.browse_local_organization),
          const SizedBox(height: 10),
          _InfoCard(
            cs: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.browse_local_recommended_structure,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _folderStructureExample,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Tips ──────────────────────────────────────────────────────────
          _InfoCard(
            cs: cs,
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.browse_local_tips,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _BulletPoint(
                  context.l10n.browse_local_tip_source(_typeName(context)),
                ),
                const SizedBox(height: 4),
                _BulletPoint(
                  context.l10n.browse_local_tip_subfolder,
                ),
                const SizedBox(height: 4),
                _BulletPoint(
                  context.l10n.browse_local_tip_cover,
                ),
                const SizedBox(height: 4),
                _BulletPoint(
                  context.l10n.browse_local_tip_pull,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final IconData icon;
  final String typeName;
  final ColorScheme cs;
  const _HeroCard({required this.icon, required this.typeName, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.browse_local_hero_title(typeName),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.browse_local_hero_subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;
  final Color? backgroundColor;
  const _InfoCard({required this.child, required this.cs, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

class _PathRow extends StatelessWidget {
  final String label;
  final String path;
  const _PathRow({required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              path,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _FormatChip({required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '.$label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSecondaryContainer,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
