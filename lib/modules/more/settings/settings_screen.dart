// Settings hub. The search spans every settings page through
// `kSettingsSearchIndex`, so a query such as "don't kill" finds the entry in
// Advanced even while the General page is open.

import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';

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
        title: l10n.reader_manga,
        icon: Broken.chrome,
        route: '/readerMode',
        keywords: ['lecture', 'reader', 'manga', 'page', 'lecteur manga'],
      ),
      _SettingItem(
        title: l10n.player_video,
        icon: Broken.play_circle,
        route: '/playerOverview',
        keywords: [
          'video',
          'vidéo',
          'player',
          'lecteur',
          'watch',
          'lecteur vidéo',
        ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final items = _buildItems(context);

    return SettingsSubpageScaffold(
      title: l10n.settings,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return ListTileWidget(
                title: item.title,
                icon: item.icon,
                onTap: () => context.push(item.route),
              );
            },
            childCount: items.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
