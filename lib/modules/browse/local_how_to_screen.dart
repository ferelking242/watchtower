import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class LocalHowToScreen extends StatelessWidget {
  final ItemType itemType;
  const LocalHowToScreen({required this.itemType, super.key});

  String get _typeName => switch (itemType) {
        ItemType.manga => 'Manga',
        ItemType.anime => 'Watch',
        ItemType.novel => 'Novel',
        ItemType.music => 'Music',
        ItemType.game => 'Game',
      };

  String get _defaultPath {
      if (!kIsWeb && Platform.isIOS) {
        // iOS sandbox: Fichiers > Sur mon iPhone > Watchtower > Local/TypeName
        return 'Sur mon iPhone → Watchtower → Local/$_typeName';
      }
      return 'Watchtower/Local/$_typeName';
    }

  List<String> get _supportedFormats => switch (itemType) {
        ItemType.manga => ['CBZ', 'ZIP'],
        ItemType.anime => ['MP4', 'MKV', 'AVI', 'MOV', 'FLV', 'MPEG', 'WMV'],
        ItemType.novel => ['EPUB'],
        ItemType.music => ['MP3', 'FLAC', 'AAC', 'OGG', 'WAV', 'M4A', 'OPUS'],
        ItemType.game => ['APK', 'ZIP', 'RAR', '7Z'],
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
      };

  IconData get _typeIcon => switch (itemType) {
        ItemType.manga => Icons.auto_stories_outlined,
        ItemType.anime => Icons.live_tv_outlined,
        ItemType.novel => Icons.menu_book_outlined,
        ItemType.music => Icons.music_note_outlined,
        ItemType.game => Icons.sports_esports_outlined,
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
        title: Text('Local $_typeName — Comment utiliser'),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          _HeroCard(icon: _typeIcon, typeName: _typeName, cs: cs),
          const SizedBox(height: 24),

          // ── Dossier ───────────────────────────────────────────────────────
          _SectionTitle('📁 Dossier local'),
          const SizedBox(height: 10),
          _InfoCard(
            cs: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PathRow(label: 'Par défaut', path: _defaultPath),
                const SizedBox(height: 8),
                _PathRow(
                    label: 'Alternatif',
                    path: !kIsWeb && Platform.isIOS
                        ? 'Sur mon iPhone → Watchtower → $_typeName'
                        : 'Download/$_typeName',
                  ),
                const SizedBox(height: 12),
                Text(
                  'Watchtower scannera ce dossier automatiquement à l\'ouverture de la source locale.',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Formats supportés ─────────────────────────────────────────────
          _SectionTitle('🗂️ Formats supportés'),
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
          _SectionTitle('🗃️ Organisation des dossiers'),
          const SizedBox(height: 10),
          _InfoCard(
            cs: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Structure recommandée :',
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
                      'Astuces',
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
                  'Ouvre la source "${_typeName} Local" dans Browse → Sources pour voir tes fichiers.',
                ),
                const SizedBox(height: 4),
                _BulletPoint(
                  'Crée un sous-dossier par titre pour une meilleure organisation.',
                ),
                const SizedBox(height: 4),
                _BulletPoint(
                  'Un fichier cover.jpg dans le dossier du titre sera utilisé comme couverture.',
                ),
                const SizedBox(height: 4),
                _BulletPoint(
                  'Tire vers le bas sur la bibliothèque locale pour rescanner les fichiers.',
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
                  'Source Locale $typeName',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lis tes fichiers locaux directement depuis ton appareil, sans connexion internet.',
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
