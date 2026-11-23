import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/live_tv/data/live_countries.dart';
import 'package:watchtower/modules/live_tv/data/live_favorites_store.dart';
import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/epg/epg_providers.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_guide_screen.dart';
import 'package:watchtower/modules/live_tv/screens/live_player_screen.dart';
import 'package:watchtower/modules/live_tv/screens/live_settings_screen.dart';
import 'package:watchtower/modules/live_tv/widgets/broken_menu_icon.dart';
import 'package:watchtower/modules/live_tv/widgets/live_common.dart';

/// Which part of Live TV the drawer selected.
enum LiveTab { home, guide, favorites, settings }

/// Live TV, laid out like a streaming app rather than a settings page.
///
/// The whole module lives behind one broken-hamburger drawer: a home with Top
/// Picks and the channel list, the EPG guide, favourites, and settings. There is
/// deliberately no extension marketplace here — providers are installed from
/// the Marketplace's Live tab, so this screen only ever shows what the user
/// already has.
class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key, this.initialTab = LiveTab.home});

  final LiveTab initialTab;

  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  late LiveTab _tab = widget.initialTab;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _country;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(LiveTab tab) {
    setState(() => _tab = tab);
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _LiveDrawer(
        current: _tab,
        onSelect: _select,
        onSearch: () {
          _scaffoldKey.currentState?.closeDrawer();
          setState(() => _tab = LiveTab.home);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchFocus.requestFocus();
          });
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              title: _titleFor(_tab),
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    LiveTab.home => _HomeTab(
                      query: _query,
                      country: _country,
                      searchController: _searchController,
                      searchFocus: _searchFocus,
                      onQuery: (value) => setState(() => _query = value),
                      onCountry: (value) => setState(() => _country = value),
                      onOpenGuide: () => _select(LiveTab.guide),
                    ),
                    LiveTab.guide => const LiveGuideScreen(embedded: true),
                    LiveTab.favorites => const _FavoritesTab(),
                    LiveTab.settings => const LiveSettingsScreen(
                      embedded: true,
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _titleFor(LiveTab tab) => switch (tab) {
    LiveTab.home => 'Live TV',
    LiveTab.guide => 'Guide des programmes',
    LiveTab.favorites => 'Favoris',
    LiveTab.settings => 'Réglages',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onMenu});

  final String title;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
      child: Row(
        children: [
          BrokenMenuIcon(onPressed: onMenu, size: 22),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawer: the module's only navigation, with the same broken mark.
class _LiveDrawer extends StatelessWidget {
  const _LiveDrawer({
    required this.current,
    required this.onSelect,
    required this.onSearch,
  });

  final LiveTab current;
  final ValueChanged<LiveTab> onSelect;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(LiveTab, IconData, String)>[
      (LiveTab.home, Icons.home_rounded, 'Accueil'),
      (LiveTab.guide, Icons.calendar_view_week_rounded, 'Guide'),
      (LiveTab.favorites, Icons.star_rounded, 'Favoris'),
      (LiveTab.settings, Icons.tune_rounded, 'Réglages'),
    ];
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.live_tv_rounded,
                      size: 19,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Live TV',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final (tab, icon, label) in items)
              _DrawerItem(
                icon: icon,
                label: label,
                selected: tab == current,
                onTap: () => onSelect(tab),
              ),
            const Spacer(),
            _DrawerItem(
              icon: Icons.search_rounded,
              label: 'Rechercher',
              selected: false,
              onTap: onSearch,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home: search, country filter, Top Picks, then every channel.
class _HomeTab extends ConsumerWidget {
  const _HomeTab({
    required this.query,
    required this.country,
    required this.searchController,
    required this.searchFocus,
    required this.onQuery,
    required this.onCountry,
    required this.onOpenGuide,
  });

  final String query;
  final String? country;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onCountry;
  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(allLiveChannelsProvider);
    final favorites = ref.watch(liveFavoritesProvider);
    final guide = ref.watch(epgProvider.select((state) => state.guide));
    final now = DateTime.now();

    return channelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LiveEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Chaînes indisponibles',
        message: '$error',
        action: FilledButton.icon(
          onPressed: () => ref.invalidate(allLiveChannelsProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ),
      data: (channels) {
        if (channels.isEmpty) {
          return const LiveEmptyState(
            icon: Icons.tv_off_rounded,
            title: 'Aucune chaîne',
            message:
                'Installez un fournisseur depuis le Marché, section Watch, '
                'ou activez-en un dans les réglages.',
          );
        }
        final countries = _countriesOf(channels);
        final filtered = _filter(channels, query, country);
        final matcher = ref.watch(epgMatcherProvider);
        EpgProgramme? nowOn(LiveChannel channel) {
          if (guide == null || matcher == null) return null;
          final id = matcher.guideIdFor(channel);
          return id == null ? null : guide.currentOn(id, now);
        }

        final picks = filtered.take(10).toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _SearchField(
                controller: searchController,
                focusNode: searchFocus,
                onChanged: onQuery,
              ),
            ),
            SliverToBoxAdapter(
              child: _CountryBar(
                countries: countries,
                selected: country,
                onSelect: onCountry,
                onOpenGuide: onOpenGuide,
                covered: guide?.channels.length ?? 0,
              ),
            ),
            if (picks.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: LiveSectionTitle(title: 'Top Picks'),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: picks.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final channel = picks[index];
                      return SizedBox(
                        width: 96,
                        child: TopPickTile(
                          channel: channel,
                          nowPlaying: nowOn(channel)?.title,
                          onTap: () => _play(context, filtered, channel),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: LiveSectionTitle(
                title: 'Toutes les chaînes',
                subtitle: '${filtered.length} chaînes',
              ),
            ),
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: LiveEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Aucune chaîne ne correspond',
                  message: 'Essayez un autre nom ou un autre pays.',
                ),
              )
            else
              SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final channel = filtered[index];
                  return ChannelRow(
                    channel: channel,
                    epg: nowOn(channel),
                    now: now,
                    isFavorite: favorites.contains(channel.id),
                    onFavorite: () => ref
                        .read(liveFavoritesProvider.notifier)
                        .toggle(channel.id),
                    onTap: () => _play(context, filtered, channel),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  static List<String> _countriesOf(List<LiveChannel> channels) {
    final set = <String>{};
    for (final channel in channels) {
      final country = channel.country ?? channel.group;
      if (country != null && country.isNotEmpty) set.add(country);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<LiveChannel> _filter(
    List<LiveChannel> channels,
    String query,
    String? country,
  ) {
    final needle = query.trim().toLowerCase();
    return [
      for (final channel in channels)
        if ((country == null ||
                (channel.country ?? channel.group) == country) &&
            (needle.isEmpty ||
                channel.name.toLowerCase().contains(needle) ||
                (channel.group ?? '').toLowerCase().contains(needle)))
          channel,
    ];
  }

  static void _play(
    BuildContext context,
    List<LiveChannel> list,
    LiveChannel channel,
  ) {
    final index = list.indexOf(channel);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerScreen(
          channels: list,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Rechercher une chaîne',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Country picker plus a shortcut to the guide.
class _CountryBar extends StatelessWidget {
  const _CountryBar({
    required this.countries,
    required this.selected,
    required this.onSelect,
    required this.onOpenGuide,
    required this.covered,
  });

  final List<String> countries;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final VoidCallback onOpenGuide;
  final int covered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<String?>(
              tooltip: 'Filtrer par pays',
              onSelected: onSelect,
              itemBuilder: (context) => [
                const PopupMenuItem(value: null, child: Text('Tous les pays')),
                for (final name in countries)
                  PopupMenuItem(
                    value: name,
                    child: Row(
                      children: [
                        flagFor(name, size: 16),
                        const SizedBox(width: 10),
                        Flexible(child: Text(name)),
                      ],
                    ),
                  ),
              ],
              child: Row(
                children: [
                  flagFor(selected, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      selected ?? 'Tous les pays',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
            ),
          ),
          if (covered > 0)
            Flexible(
              child: Text(
                'Heure locale : ${clockLabel(DateTime.now())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ouvrir le guide',
            onPressed: onOpenGuide,
            icon: const Icon(Icons.calendar_view_week_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Favourites: the channels the user starred, with what is airing now.
class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(liveFavoritesProvider);
    final channelsAsync = ref.watch(allLiveChannelsProvider);
    final guide = ref.watch(epgProvider.select((state) => state.guide));
    final matcher = ref.watch(epgMatcherProvider);
    final now = DateTime.now();

    return channelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LiveEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Chaînes indisponibles',
        message: '$error',
      ),
      data: (channels) {
        final starred = [
          for (final channel in channels)
            if (favorites.contains(channel.id)) channel,
        ];
        if (starred.isEmpty) {
          return const LiveEmptyState(
            icon: Icons.star_border_rounded,
            title: 'Aucun favori',
            message: 'Touchez l\'étoile d\'une chaîne pour la retrouver ici.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: starred.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
          itemBuilder: (context, index) {
            final channel = starred[index];
            final guideId = matcher?.guideIdFor(channel);
            return ChannelRow(
              channel: channel,
              epg: guideId == null ? null : guide?.currentOn(guideId, now),
              now: now,
              isFavorite: true,
              onFavorite: () =>
                  ref.read(liveFavoritesProvider.notifier).toggle(channel.id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      LivePlayerScreen(channels: starred, initialIndex: index),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
