// Copied structure from namidaco/namida — lib/ui/pages/settings_page.dart
// Adapted for Watchtower: GetX → Riverpod, NamidaNavigator → GoRouter,
// settings search animation adapted from Namida's AppBar search pattern.

import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/more/widgets/list_tile_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';

// Namida settings items — adapted as static list for Watchtower's search
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

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // Copied from Namida settings search pattern: animated search bar
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  late final AnimationController _animCtrl;
  late final Animation<double> _widthAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    // Copied animation setup from Namida search bar pattern
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _widthAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _opacityAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    _animCtrl.forward();
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _animCtrl.reverse().then((_) {
      setState(() {
        _searchOpen = false;
        _query = '';
      });
      _searchCtrl.clear();
    });
  }

  List<_SettingItem> _buildItems(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return [
      _SettingItem(
        title: l10n.general,
        icon: Icons.settings,
        route: '/general',
        keywords: ['général', 'general'],
      ),
      _SettingItem(
        title: l10n.appearance,
        icon: Icons.color_lens_rounded,
        route: '/appearance',
        keywords: ['apparence', 'thème', 'theme', 'couleur', 'color', 'police', 'font', 'sombre', 'dark', 'clair', 'light'],
      ),
      _SettingItem(
        title: 'Lecteur Manga',
        icon: Icons.chrome_reader_mode_rounded,
        route: '/readerMode',
        keywords: ['lecture', 'reader', 'manga', 'page'],
      ),
      _SettingItem(
        title: 'Lecteur Vidéo',
        icon: Icons.play_circle_outline_outlined,
        route: '/playerOverview',
        keywords: ['video', 'vidéo', 'player', 'lecteur', 'watch'],
      ),
      _SettingItem(
        title: l10n.downloads,
        icon: Icons.download_outlined,
        route: '/downloads',
        keywords: ['téléchargement', 'download'],
      ),
      _SettingItem(
        title: l10n.tracking,
        icon: Icons.sync_outlined,
        route: '/track',
        keywords: ['tracking', 'suivi', 'anilist', 'myanimelist', 'mal'],
      ),
      _SettingItem(
        title: l10n.syncing,
        icon: Icons.cloud_sync_outlined,
        route: '/sync',
        keywords: ['sync', 'synchronisation', 'cloud'],
      ),
      _SettingItem(
        title: l10n.browse,
        icon: Icons.explore_rounded,
        route: '/browseS',
        keywords: ['browse', 'explorer', 'source', 'extension'],
      ),
      if (kIsWeb || !Platform.isLinux)
        _SettingItem(
          title: l10n.security,
          icon: Icons.security_rounded,
          route: '/security',
          keywords: ['sécurité', 'security', 'mdp', 'mot de passe', 'biométrie'],
        ),
      _SettingItem(
        title: 'Sources Locales',
        icon: Icons.folder_open_rounded,
        route: '/localSources',
        keywords: ['local', 'dossier', 'folder', 'fichier', 'file'],
      ),
      _SettingItem(
        title: 'Avancé',
        icon: Icons.tune_rounded,
        route: '/advanced',
        keywords: ['avancé', 'advanced', 'debug', 'cache', 'logs'],
      ),
      _SettingItem(
        title: 'Music Hub',
        icon: Icons.music_note_rounded,
        route: '/MusicLibrary',
        keywords: ['musique', 'music', 'audio', 'namida'],
      ),
      if (kIsWeb)
        _SettingItem(
          title: 'Connexion Distante',
          icon: Icons.link_rounded,
          route: '/remoteSetup',
          keywords: ['remote', 'distant', 'connexion', 'web'],
        )
      else
        _SettingItem(
          title: 'Mode Distant',
          icon: Icons.wifi_tethering_rounded,
          route: '/remoteMode',
          keywords: ['remote', 'distant', 'wifi', 'tethering'],
        ),
      _SettingItem(
        title: l10n.about,
        icon: Icons.info_outline,
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

    // Copied AppBar search animation from Namida's SubpagesTopContainer pattern
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        // Namida-style: title animates out, search field animates in
        title: _searchOpen
            ? SizeTransition(
                sizeFactor: _widthAnim,
                axis: Axis.horizontal,
                child: FadeTransition(
                  opacity: _opacityAnim,
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    style: Theme.of(context).textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              )
            : Text(l10n.settings),
        actions: [
          // Namida: animated search icon → close icon transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _searchOpen
                ? IconButton(
                    key: const ValueKey('close'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _closeSearch,
                    tooltip: 'Fermer',
                  )
                : IconButton(
                    key: const ValueKey('search'),
                    icon: const Icon(Icons.search_rounded),
                    onPressed: _openSearch,
                    tooltip: 'Rechercher',
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: visible.isEmpty
            ? Center(
                key: const ValueKey('empty'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun résultat pour "$_query"',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
            : ListView(
                key: ValueKey(_query),
                children: visible
                    .map(
                      (item) => ListTileWidget(
                        title: item.title,
                        icon: item.icon,
                        onTap: () => context.push(item.route),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
