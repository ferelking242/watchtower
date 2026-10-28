// Settings hub. The search spans every settings page through
// `kSettingsSearchIndex`, so a query such as "don't kill" finds the entry in
// Advanced even while the General page is open.

import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_search_index.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/more/widgets/list_tile_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';

class _SettingItem {
  final String title;
  final IconData icon;
  final String route;
  final List<String> keywords;

  const _SettingItem({
    required this.title,
    required this.icon,
    required this.route,
    this.keywords = const [],
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_SettingItem> _buildItems(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return [
      _SettingItem(
        title: l10n.general,
        icon: Broken.setting_2,
        route: '/general',
        keywords: ['général', 'general'],
      ),
      _SettingItem(
        title: l10n.display,
        icon: Broken.monitor,
        route: '/appearance',
        keywords: [
          'affichage',
          'display',
          'apparence',
          'appearance',
          'thème',
          'theme',
          'couleur',
          'color',
          'police',
          'font',
          'sombre',
          'dark',
          'clair',
          'light',
        ],
      ),
      _SettingItem(
        title: l10n.library,
        icon: Broken.book_1,
        route: '/librarySettings',
        keywords: [
          'bibliothèque',
          'library',
          'catégorie',
          'category',
          'tri',
          'sort',
          'mise à jour',
          'update',
        ],
      ),
      _SettingItem(
        title: l10n.reader,
        icon: Broken.chrome,
        route: '/readerMode',
        keywords: ['lecture', 'reader', 'manga', 'page'],
      ),
      _SettingItem(
        title: l10n.player,
        icon: Broken.play_circle,
        route: '/playerOverview',
        keywords: ['video', 'vidéo', 'player', 'lecteur', 'watch'],
      ),
      _SettingItem(
        title: l10n.downloads,
        icon: Broken.document_download,
        route: '/downloads',
        keywords: ['téléchargement', 'download'],
      ),
      _SettingItem(
        title: l10n.tracking,
        icon: Broken.refresh_circle,
        route: '/track',
        keywords: ['tracking', 'suivi', 'anilist', 'myanimelist', 'mal'],
      ),
      _SettingItem(
        title: l10n.syncing,
        icon: Broken.cloud_connection,
        route: '/sync',
        keywords: ['sync', 'synchronisation', 'cloud'],
      ),
      _SettingItem(
        title: l10n.browse,
        icon: Broken.global_search,
        route: '/browseS',
        keywords: ['browse', 'explorer', 'source', 'extension'],
      ),
      if (kIsWeb || !Platform.isLinux)
        _SettingItem(
          title: l10n.security,
          icon: Broken.shield_tick,
          route: '/security',
          keywords: ['sécurité', 'security', 'mdp', 'mot de passe', 'biométrie'],
        ),
      _SettingItem(
        title: 'Sources Locales',
        icon: Broken.folder_open,
        route: '/localSources',
        keywords: ['local', 'dossier', 'folder', 'fichier', 'file'],
      ),
      _SettingItem(
        title: l10n.advanced,
        icon: Broken.setting_4,
        route: '/advanced',
        keywords: ['avancé', 'advanced', 'debug', 'cache', 'logs'],
      ),
      _SettingItem(
        title: 'Music Hub',
        icon: Broken.music_playlist,
        route: '/MusicLibrary',
        keywords: ['musique', 'music', 'audio', 'namida'],
      ),
      if (kIsWeb)
        _SettingItem(
          title: 'Connexion Distante',
          icon: Broken.link,
          route: '/remoteSetup',
          keywords: ['remote', 'distant', 'connexion', 'web'],
        )
      else
        _SettingItem(
          title: 'Mode Distant',
          icon: Broken.wifi_square,
          route: '/remoteMode',
          keywords: ['remote', 'distant', 'wifi', 'tethering'],
        ),
      _SettingItem(
        title: l10n.about,
        icon: Broken.info_circle,
        route: '/about',
        keywords: ['à propos', 'about', 'version', 'info'],
      ),
    ];
  }

  List<_SettingItem> _filtered(List<_SettingItem> items) {
    if (_query.isEmpty) return items;
    return items.where((item) {
      return item.title.toLowerCase().contains(_query) ||
          item.keywords.any((k) => k.contains(_query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final items = _buildItems(context);
    final visible = _filtered(items);

    return SettingsSubpageScaffold(
      title: l10n.settings,
      expandedHeight: 96,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher dans les paramètres…',
                prefixIcon: const Icon(Broken.search_normal, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Broken.close_circle, size: 20),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        if (_query.isNotEmpty)
          SliverToBoxAdapter(child: _CrossPageResults(query: _query)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = visible[index];
              return ListTileWidget(
                title: item.title,
                icon: item.icon,
                onTap: () => context.push(item.route),
              );
            },
            childCount: visible.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Extra results found on *other* settings pages for the current query.
class _CrossPageResults extends StatelessWidget {
  const _CrossPageResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = kSettingsSearchIndex
        .where((e) => e.matches(query))
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Résultats dans les sous-pages',
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
            onTap: () => context.push(e.route),
          ),
        ),
        const Divider(height: 16, indent: 16, endIndent: 16),
      ],
    );
  }
}
