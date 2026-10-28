import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/catalog_filter_sheet.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';
import 'package:watchtower/modules/media/overlay_filter_menu.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

const _tmdbBackground = Color(0xFF0B0B11);

class TmdbCastCrewScreen extends StatefulWidget {
  final TmdbMedia media;

  const TmdbCastCrewScreen({super.key, required this.media});

  @override
  State<TmdbCastCrewScreen> createState() => _TmdbCastCrewScreenState();
}

class _TmdbCastCrewScreenState extends State<TmdbCastCrewScreen> {
  late Future<TmdbMediaDetails> _details;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _details = fetchTmdbMediaDetails(widget.media);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tmdbBackground,
      body: FutureBuilder<TmdbMediaDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PeopleLoading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'Impossible de charger la distribution.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final details = snapshot.data!;
          final isCrew = _tabIndex == 1;
          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 18, 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Retour',
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Broken.arrow_left,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Cast And Crew',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _CastCrewSwitcher(
                    index: _tabIndex,
                    onChanged: (index) => setState(() => _tabIndex = index),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _CastCrewPeopleList(
                      key: ValueKey(_tabIndex),
                      media: widget.media,
                      details: details,
                      crew: isCrew,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CastCrewSwitcher extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _CastCrewSwitcher({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E22),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _CastCrewTab(
            selected: index == 0,
            icon: Icons.people_outline_rounded,
            label: 'Cast',
            onTap: () => onChanged(0),
          ),
          _CastCrewTab(
            selected: index == 1,
            icon: Icons.handyman_outlined,
            label: 'Crew',
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _CastCrewTab extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CastCrewTab({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF8DDBB7) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF101714) : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF101714) : Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CastCrewPeopleList extends StatelessWidget {
  final TmdbMedia media;
  final TmdbMediaDetails details;
  final bool crew;

  const _CastCrewPeopleList({
    super.key,
    required this.media,
    required this.details,
    required this.crew,
  });

  @override
  Widget build(BuildContext context) {
    if (crew && details.crew.isEmpty || !crew && details.cast.isEmpty) {
      return const _PeopleEmpty();
    }
    final count = crew ? details.crew.length : details.cast.length;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final castPerson = crew ? null : details.cast[index];
        final crewPerson = crew ? details.crew[index] : null;
        final personName = crewPerson?.name ?? castPerson!.name;
        final personImage = crewPerson?.profileUrl ?? castPerson!.profileUrl;
        final personId = crewPerson?.id ?? castPerson!.id;
        final personProfilePath =
            crewPerson?.profilePath ?? castPerson!.profilePath;
        final subtitle = crew
            ? 'Job : ${crewPerson!.job.isNotEmpty ? crewPerson.job : 'N/A'}'
            : 'As : ${castPerson!.character.isNotEmpty ? castPerson.character : 'N/A'}';
        final episodeLabel =
            !crew &&
                media.mediaType == 'tv' &&
                (details.numberOfEpisodes ?? 0) > 0
            ? '${details.numberOfEpisodes} épisodes'
            : null;
        return _CastCrewPersonCard(
          imageUrl: personImage,
          name: personName,
          subtitle: subtitle,
          meta: episodeLabel,
          onTap: () => context.push(
            '/flixPerson',
            extra: TmdbPersonRef(
              id: personId,
              name: personName,
              profilePath: personProfilePath,
            ),
          ),
        );
      },
    );
  }
}

class _CastCrewPersonCard extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String subtitle;
  final String? meta;
  final VoidCallback onTap;

  const _CastCrewPersonCard({
    required this.imageUrl,
    required this.name,
    required this.subtitle,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF202126),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: imageUrl == null
                      ? const ColoredBox(
                          color: Color(0xFF54565B),
                          child: Icon(Broken.user, color: Colors.black54),
                        )
                      : ExtendedImage.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          cache: true,
                          loadStateChanged: (state) =>
                              state.extendedImageLoadState ==
                                  LoadState.completed
                              ? null
                              : const AppShimmerBlock(radius: 40),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Broken.arrow_right_3, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class TmdbPersonScreen extends ConsumerStatefulWidget {
  final TmdbPersonRef person;
  final Source? extensionSource;
  final MManga? extensionPerson;

  const TmdbPersonScreen({
    super.key,
    required this.person,
    this.extensionSource,
    this.extensionPerson,
  });

  @override
  ConsumerState<TmdbPersonScreen> createState() => _TmdbPersonScreenState();
}

class _TmdbPersonScreenState extends ConsumerState<TmdbPersonScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  late Future<TmdbPersonDetails> _details;
  Future<MManga>? _extensionDetails;

  bool get _isExtensionProfile =>
      widget.extensionSource != null && widget.extensionPerson != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _isExtensionProfile ? 2 : 3,
      vsync: this,
    )..addListener(_onTabChanged);
    if (_isExtensionProfile) {
      final source = widget.extensionSource!;
      final profile = widget.extensionPerson!;
      _extensionDetails = ref.read(
        getDetailProvider(url: profile.link ?? '', source: source).future,
      );
    } else {
      _details = fetchTmdbPersonDetails(widget.person);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isExtensionProfile) {
      return Scaffold(
        backgroundColor: _tmdbBackground,
        body: FutureBuilder<MManga>(
          future: _extensionDetails,
          builder: (context, snapshot) =>
              _buildExtensionProfile(context, snapshot.data),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _tmdbBackground,
      body: FutureBuilder<TmdbPersonDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PeopleLoading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'Impossible de charger cette fiche.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final person = snapshot.data!;
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: 330,
                toolbarHeight: 64,
                backgroundColor: _tmdbBackground,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                leadingWidth: 68,
                leading: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: _PersonHeroButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => context.pop(),
                  ),
                ),
                title: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, _) {
                    final visible =
                        _scrollController.hasClients &&
                        _scrollController.offset > 250;
                    return AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  stretchModes: const [StretchMode.zoomBackground],
                  background: _PersonHero(person: person),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PersonTabsDelegate(controller: _tabController),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 44),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_tabController.index),
                      child: _buildTab(context, person),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTab(BuildContext context, TmdbPersonDetails person) {
    switch (_tabController.index) {
      case 1:
        return _PersonCreditsGrid(
          title: 'films',
          credits: person.movies,
          onTap: (media) => context.push('/flixMediaDetail', extra: media),
        );
      case 2:
        return _PersonCreditsGrid(
          title: 'séries',
          credits: person.tvShows,
          onTap: (media) => context.push('/flixMediaDetail', extra: media),
        );
      default:
        return _PersonAboutTab(person: person);
    }
  }

  Widget _buildExtensionProfile(BuildContext context, MManga? details) {
    final profile = widget.extensionPerson!;
    final title = details?.name?.trim().isNotEmpty == true
        ? details!.name!.trim()
        : (profile.name?.trim().isNotEmpty == true
              ? profile.name!.trim()
              : 'Profil');
    final image = details?.imageUrl?.trim().isNotEmpty == true
        ? details!.imageUrl!.trim()
        : profile.imageUrl?.trim();
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: 330,
          toolbarHeight: 64,
          backgroundColor: _tmdbBackground,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leadingWidth: 68,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: _PersonHeroButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.pop(),
            ),
          ),
          title: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, _) {
              final visible =
                  _scrollController.hasClients &&
                  _scrollController.offset > 250;
              return AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [StretchMode.zoomBackground],
            background: _ExtensionPersonHero(name: title, imageUrl: image),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PersonTabsDelegate(
            controller: _tabController,
            labels: const ['About', 'Movies'],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 44),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_tabController.index),
                child: _tabController.index == 0
                    ? _ExtensionPersonAbout(item: profile, details: details)
                    : _ExtensionPersonVideos(
                        profile: profile,
                        details: details,
                        source: widget.extensionSource,
                        scrollController: _scrollController,
                        onOpen: (video) => _openExtensionVideo(video),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openExtensionVideo(MChapter video) async {
    final source = widget.extensionSource!;
    final profile = widget.extensionPerson!;
    final url = video.url?.trim();
    if (url == null || url.isEmpty) return;
    final name = video.name?.trim();
    final item = MManga(
      name: name?.isNotEmpty == true ? name : url,
      link: url,
      imageUrl: video.thumbnailUrl ?? profile.imageUrl,
      status: Status.unknown,
    );
    await pushToMangaReaderDetail(
      ref: ref,
      context: context,
      getManga: item,
      lang: source.lang ?? '',
      source: source.name ?? '',
      sourceId: source.id,
      itemType: source.itemType,
    );
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ExtensionPersonHero extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _ExtensionPersonHero({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image == null || image.isEmpty)
          const ColoredBox(color: Color(0xFF25252A))
        else
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: ExtendedImage.network(
              image,
              fit: BoxFit.cover,
              cache: true,
              loadStateChanged: (state) =>
                  state.extendedImageLoadState == LoadState.completed
                  ? null
                  : const AppShimmerBlock(radius: 0),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0xF5000000)],
              stops: [0.05, 1],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 62, 18, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActorAvatar(url: image),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionPersonAbout extends StatelessWidget {
  final MManga item;
  final MManga? details;

  const _ExtensionPersonAbout({required this.item, required this.details});

  @override
  Widget build(BuildContext context) {
    final description = details?.description?.trim().isNotEmpty == true
        ? details!.description!.trim()
        : item.description?.trim();
    final genres = <String>{
      ...(details?.genre ?? const <String>[]),
      ...(item.genre ?? const <String>[]),
    }.where((value) => value.trim().isNotEmpty).toList(growable: false);
    final author = details?.author?.trim();
    final artist = details?.artist?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PeopleSectionTitle(title: 'About'),
        const SizedBox(height: 10),
        Text(
          description?.isNotEmpty == true
              ? description!
              : 'Aucune description disponible.',
          style: const TextStyle(color: Colors.white70, height: 1.55),
        ),
        if ((author?.isNotEmpty == true) || (artist?.isNotEmpty == true)) ...[
          const SizedBox(height: 20),
          if (author?.isNotEmpty == true)
            _ExtensionInfoLine(label: 'Author', value: author!),
          if (artist?.isNotEmpty == true)
            _ExtensionInfoLine(label: 'Artist', value: artist!),
        ],
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _PeopleSectionTitle(title: 'Tags'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in genres)
                Chip(
                  label: Text(genre),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF20212A),
                  side: BorderSide(color: Colors.white.withValues(alpha: .12)),
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ExtensionInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _ExtensionInfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

/// "Movies" tab of an extension person page. Renders the profile's videos as
/// a grid by default and exposes the same filter sheet and three-dot menu as
/// the "see all" catalogue, so the page behaves like every other catalogue
/// surface instead of a bare fixed list with a download-all button.
class _ExtensionPersonVideos extends ConsumerStatefulWidget {
  final MManga profile;
  final MManga? details;
  final Source? source;
  final ScrollController scrollController;
  final ValueChanged<MChapter> onOpen;

  const _ExtensionPersonVideos({
    required this.profile,
    required this.details,
    required this.source,
    required this.scrollController,
    required this.onOpen,
  });

  @override
  ConsumerState<_ExtensionPersonVideos> createState() =>
      _ExtensionPersonVideosState();
}

class _ExtensionPersonVideosState extends ConsumerState<_ExtensionPersonVideos> {
  CatalogFilterState _filter = CatalogFilterState();
  final List<MChapter> _extra = [];
  int _page = 1;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _loadMoreError;

  MManga get _details => widget.details ?? widget.profile;

  List<MChapter> get _videos => [
    ...(_details.chapters ?? const <MChapter>[]),
    ..._extra,
  ].where((video) => video.url?.trim().isNotEmpty == true).toList(growable: false);

  /// `profile_<hex of the profile path>` — the extension pages a profile
  /// listing with the same zero-based JSON endpoint the first page uses.
  String? get _profileListId {
    final link = widget.profile.link?.trim();
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    final path = uri?.path;
    if (path == null || path.isEmpty) return null;
    final buffer = StringBuffer('profile_');
    for (final rune in path.runes) {
      buffer.write(rune.toRadixString(16).padLeft(4, '0'));
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients || _loadingMore || !_hasMore) {
      return;
    }
    final position = widget.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 480) _loadMore();
  }

  Future<void> _loadMore() async {
    final listId = _profileListId;
    final source = widget.source;
    if (listId == null || source == null || _loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    try {
      final nextPage = _page + 1;
      final pages = await ref.read(
        getCustomListProvider(
          source: source,
          listId: listId,
          page: nextPage,
        ).future,
      );
      if (!mounted) return;
      final known = _videos.map((video) => video.url).toSet();
      final fresh = (pages?.list ?? const <MManga>[])
          .where((item) => item.link?.trim().isNotEmpty == true)
          .where((item) => !known.contains(item.link!.trim()))
          .map(
            (item) => MChapter(
              name: item.name,
              url: item.link,
              thumbnailUrl: item.imageUrl,
              duration: item.description?.replaceFirst('Duration: ', ''),
            ),
          )
          .toList(growable: false);
      setState(() {
        _page = nextPage;
        _extra.addAll(fresh);
        _hasMore = (pages?.hasNextPage ?? false) && fresh.isNotEmpty;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error;
      });
    }
  }

  /// Videos matching the length preset chosen in the filter sheet.
  ///
  /// The sheet's generic sections (years, genres, sort) have no meaning for a
  /// flat list of videos, so the length preset is carried by the "type" field
  /// and the sheet is shown without the others. A video whose duration cannot
  /// be parsed is kept: hiding it would look like a missing video rather than
  /// a filtered one.
  List<MChapter> _visible(List<MChapter> videos) {
    final minimumMinutes = int.tryParse(_filter.type);
    if (minimumMinutes == null) return videos;
    return videos.where((video) {
      final duration = _parseDuration(video.duration);
      return duration == null || duration.inMinutes >= minimumMinutes;
    }).toList(growable: false);
  }

  static Duration? _parseDuration(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    return Duration(minutes: minutes, seconds: seconds);
  }

  /// Length presets carried by the sheet's "type" section: the values are the
  /// minimum minutes a video must run for, and `all` clears the filter.
  List<CatalogTypeOption> get _typeOptions => const [
    CatalogTypeOption('Toutes', 'all'),
    CatalogTypeOption('10 min +', '10'),
    CatalogTypeOption('20 min +', '20'),
    CatalogTypeOption('40 min +', '40'),
  ];

  Widget _buildFilterButton() {
    return AdaptiveOverlayMenuButton(
      menuWidth: 300,
      trigger: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          Broken.filter,
          color: _filter.isDefault ? null : Colors.orange,
        ),
      ),
      contentBuilder: (close) => CatalogFilterOverlay(
        initial: _filter,
        typeOptions: _typeOptions,
        sortOptions: const [],
        genreOptions: const [],
        showYearsSection: false,
        showRatingSection: false,
        showGenreSection: false,
        showSortSection: false,
        close: close,
        onChanged: (value) => setState(() => _filter = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;
    if (videos.isEmpty) return const _PeopleEmpty();
    final visible = _visible(videos);
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isFrench
                    ? '${videos.length} vidéos${_hasMore ? '+' : ''}'
                    : '${videos.length} videos${_hasMore ? '+' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildFilterButton(),
            // Same three-dot menu as the "see all" catalogue, minus the
            // download entries.
            AdaptiveOverlayMenu<CatalogBulkDownloadAction>(
              tooltip: isFrench ? 'Options' : 'Options',
              icon: const Icon(Broken.more_2),
              menuWidth: 240,
              onSelected: (_) {},
              itemBuilder: (_) => CatalogBulkDownload.selectionMenuItems(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildItems(context, visible),
        if (_hasMore || _loadMoreError != null) _buildFooter(context),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() => _loadMoreError = null);
              _loadMore();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              isFrench ? 'Chargement échoué · Réessayer' : 'Load failed · Retry',
            ),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.only(top: 18),
      child: Center(child: AppShimmerBlock(radius: AppUI.cardRadius)),
    );
  }

  Widget _buildItems(BuildContext context, List<MChapter> visible) {
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'Aucune vidéo ne correspond au filtre.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      );
    }
    if (_filter.layout == CatalogLayout.list) {
      return Column(
        children: [
          for (final video in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFF171820),
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  onTap: () => widget.onOpen(video),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 46,
                      child: ContentImage(
                        url: _thumbnail(video),
                        radius: 8,
                      ),
                    ),
                  ),
                  title: Text(
                    _title(video),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: _duration(video) == null
                      ? null
                      : Text(
                          _duration(video)!,
                          style: const TextStyle(color: Colors.white54),
                        ),
                ),
              ),
            ),
        ],
      );
    }
    final columns = AppUI.mediaGridColumns(context);
    final count = _filter.layout == CatalogLayout.comfortable
        ? (columns - 1).clamp(1, columns)
        : columns;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        childAspectRatio: 1.25,
        crossAxisSpacing: AppUI.mediaGridCrossAxisSpacing,
        mainAxisSpacing: 14,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final video = visible[index];
        return LandscapeCard(
          item: _item(video),
          width: double.infinity,
          onTap: () => widget.onOpen(video),
        );
      },
    );
  }

  String _title(MChapter video) {
    final name = video.name?.trim();
    return name?.isNotEmpty == true ? name! : 'Video';
  }

  String? _duration(MChapter video) {
    final value = video.duration?.trim();
    return value?.isNotEmpty == true ? value : null;
  }

  ContentItem _item(MChapter video) => ContentItem(
    key: 'extension-video-${video.url ?? video.hashCode}',
    title: _title(video),
    posterUrl: _thumbnail(video),
    backdropUrl: _thumbnail(video),
    description: _duration(video),
  );

  String? _thumbnail(MChapter video) {
    for (final candidate in [
      video.thumbnailUrl,
      _details.imageUrl,
      widget.profile.imageUrl,
    ]) {
      final value = candidate?.trim();
      if (value?.isNotEmpty == true) return value;
    }
    return null;
  }
}


class _PersonHero extends StatelessWidget {
  final TmdbPersonDetails person;

  const _PersonHero({required this.person});

  @override
  Widget build(BuildContext context) {
    final image = person.profileUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image == null)
          const ColoredBox(color: Color(0xFF25252A))
        else
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: ExtendedImage.network(
              image,
              fit: BoxFit.cover,
              cache: true,
              loadStateChanged: (state) =>
                  state.extendedImageLoadState == LoadState.completed
                  ? null
                  : const AppShimmerBlock(radius: 0),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0xF5000000)],
              stops: [0.05, 1],
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 62, 18, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActorAvatar(url: image),
                  const SizedBox(height: 12),
                  Text(
                    person.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                    ),
                  ),
                  if (person.knownForDepartment?.isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .42),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: Text(
                          person.knownForDepartment!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonHeroButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _PersonHeroButton({required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black.withValues(alpha: .38),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          color: Colors.white,
          icon: const Icon(Broken.arrow_left_3, size: 21),
        ),
      ),
    );
  }
}

class _PersonTabsDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final List<String> labels;

  const _PersonTabsDelegate({
    required this.controller,
    this.labels = const ['About', 'Movies', 'TV Shows'],
  });

  @override
  double get minExtent => 58;

  @override
  double get maxExtent => 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.black,
      elevation: overlapsContent ? 2 : 0,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              _PersonTab(
                label: labels[index],
                selected: controller.index == index,
                onTap: () => controller.animateTo(index),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PersonTabsDelegate oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.labels != labels;
}

class _PersonTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PersonTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFF8A00) : Colors.white70,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 9),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 30 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonAboutTab extends StatelessWidget {
  final TmdbPersonDetails person;

  const _PersonAboutTab({required this.person});

  @override
  Widget build(BuildContext context) {
    final images = person.profilePaths.isEmpty && person.profileUrl != null
        ? [person.profilePath!]
        : person.profilePaths;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PeopleSectionTitle(title: 'Biography'),
        const SizedBox(height: 10),
        _ExpandableBiography(text: person.biography),
        const SizedBox(height: 25),
        _PersonInfoGrid(person: person),
        const SizedBox(height: 25),
        if (images.isNotEmpty) ...[
          const _PeopleSectionTitle(title: 'Images'),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _PersonImage(path: images[index]),
            ),
          ),
          const SizedBox(height: 25),
        ],
        const _PeopleSectionTitle(title: 'Social media links'),
        const SizedBox(height: 11),
        _PersonSocialLinks(person: person),
      ],
    );
  }
}

class _ExpandableBiography extends StatefulWidget {
  final String? text;

  const _ExpandableBiography({required this.text});

  @override
  State<_ExpandableBiography> createState() => _ExpandableBiographyState();
}

class _ExpandableBiographyState extends State<_ExpandableBiography> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text?.trim();
    if (text == null || text.isEmpty) {
      return const Text(
        'Aucune biographie disponible.',
        style: TextStyle(color: Colors.white60, height: 1.5),
      );
    }
    final canExpand = text.length > 260;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded ? null : 5,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.42,
          ),
        ),
        if (canExpand)
          GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                expanded ? 'read less' : 'read more',
                style: const TextStyle(
                  color: Color(0xFFFF8A00),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PersonInfoGrid extends StatelessWidget {
  final TmdbPersonDetails person;

  const _PersonInfoGrid({required this.person});

  @override
  Widget build(BuildContext context) {
    final cards = <_PersonInfoData>[
      _PersonInfoData(
        icon: Broken.cake,
        label: 'Age',
        value: _age(person.birthday, person.deathday),
      ),
      _PersonInfoData(
        icon: Broken.calendar,
        label: 'Born on',
        value: _formatDate(person.birthday),
      ),
      _PersonInfoData(
        icon: Broken.location,
        label: 'From',
        value: person.placeOfBirth?.trim().isNotEmpty == true
            ? person.placeOfBirth!
            : '—',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 84),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              card.icon,
                              color: const Color(0xFFFF8A00),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              card.label,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PersonInfoData {
  final IconData icon;
  final String label;
  final String value;

  const _PersonInfoData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _ActorAvatar extends StatelessWidget {
  final String? url;

  const _ActorAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: .85),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: url == null
            ? const ColoredBox(
                color: Color(0xFF25252A),
                child: Icon(Broken.user, color: Colors.white54, size: 32),
              )
            : ExtendedImage.network(
                url!,
                fit: BoxFit.cover,
                cache: true,
                loadStateChanged: (state) =>
                    state.extendedImageLoadState == LoadState.completed
                    ? null
                    : const AppShimmerBlock(radius: 60),
              ),
      ),
    );
  }
}

class _PersonImage extends StatelessWidget {
  final String path;

  const _PersonImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 113,
        child: ExtendedImage.network(
          'https://image.tmdb.org/t/p/w300$path',
          fit: BoxFit.cover,
          cache: true,
          loadStateChanged: (state) =>
              state.extendedImageLoadState == LoadState.completed
              ? null
              : const AppShimmerBlock(radius: 0),
        ),
      ),
    );
  }
}

class _PersonSocialLinks extends StatelessWidget {
  final TmdbPersonDetails person;

  const _PersonSocialLinks({required this.person});

  @override
  Widget build(BuildContext context) {
    final links = <_PersonSocialLink>[
      if (person.facebookId?.isNotEmpty == true)
        _PersonSocialLink(
          label: 'Facebook',
          icon: Broken.global,
          url: 'https://www.facebook.com/${person.facebookId}',
        ),
      if (person.instagramId?.isNotEmpty == true)
        _PersonSocialLink(
          label: 'Instagram',
          icon: Broken.instagram,
          url: 'https://www.instagram.com/${person.instagramId}',
        ),
      if (person.twitterId?.isNotEmpty == true)
        _PersonSocialLink(
          label: 'X',
          icon: Broken.global,
          url: 'https://x.com/${person.twitterId}',
        ),
      if (person.imdbId?.isNotEmpty == true)
        _PersonSocialLink(
          label: 'IMDb',
          icon: Broken.video,
          url: 'https://www.imdb.com/name/${person.imdbId}',
        ),
      if (person.homepage?.isNotEmpty == true)
        _PersonSocialLink(
          label: 'Website',
          icon: Broken.link,
          url: person.homepage!,
        ),
    ];
    if (links.isEmpty) {
      return const Text(
        'Aucun lien disponible.',
        style: TextStyle(color: Colors.white54),
      );
    }
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: links
          .map(
            (link) => OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(link.url),
                mode: LaunchMode.externalApplication,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF8A00),
                side: const BorderSide(color: Color(0xFFFF8A00)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
              ),
              icon: Icon(link.icon, size: 16),
              label: Text(
                link.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PersonSocialLink {
  final String label;
  final IconData icon;
  final String url;

  const _PersonSocialLink({
    required this.label,
    required this.icon,
    required this.url,
  });
}

class _PersonCreditsGrid extends StatelessWidget {
  final String title;
  final List<TmdbMedia> credits;
  final ValueChanged<TmdbMedia> onTap;

  const _PersonCreditsGrid({
    required this.title,
    required this.credits,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (credits.isEmpty) {
      return const _PeopleEmpty();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${credits.length} $title',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: credits.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisExtent: 252,
            crossAxisSpacing: 12,
            mainAxisSpacing: 18,
          ),
          itemBuilder: (_, index) => _PersonCreditCard(
            media: credits[index],
            onTap: () => onTap(credits[index]),
          ),
        ),
      ],
    );
  }
}

class _PersonCreditCard extends StatelessWidget {
  final TmdbMedia media;
  final VoidCallback onTap;

  const _PersonCreditCard({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.bestCover != null)
                    ExtendedImage.network(
                      media.bestCover!,
                      fit: BoxFit.cover,
                      cache: true,
                      loadStateChanged: (state) =>
                          state.extendedImageLoadState == LoadState.completed
                          ? null
                          : const AppShimmerBlock(radius: 0),
                    )
                  else
                    const ColoredBox(
                      color: Color(0xFF25252A),
                      child: Icon(Broken.video, color: Colors.white54),
                    ),
                  if (media.voteAverage != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8A00),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Text(
                            media.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            media.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(String? raw) {
  final date = raw == null ? null : DateTime.tryParse(raw);
  if (date == null) return '—';
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${date.day} ${months[date.month - 1]}, ${date.year}';
}

String _age(String? birthday, String? deathday) {
  final born = birthday == null ? null : DateTime.tryParse(birthday);
  if (born == null) return '—';
  final end = deathday == null
      ? DateTime.now()
      : DateTime.tryParse(deathday) ?? DateTime.now();
  var age = end.year - born.year;
  if (end.month < born.month ||
      (end.month == born.month && end.day < born.day)) {
    age--;
  }
  return age < 0 ? '—' : '$age';
}

class _CastCrewRow extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _CastCrewRow({
    required this.imageUrl,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      onTap: onTap,
      leading: _PersonAvatar(url: imageUrl),
      title: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle.isEmpty ? '—' : subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: const Icon(Broken.arrow_right_3, color: Colors.white38),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String? url;
  final bool large;

  const _PersonAvatar({required this.url, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 132.0 : 54.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(large ? 16 : 12),
      child: SizedBox(
        width: size,
        height: large ? 176 : size,
        child: url == null
            ? const ColoredBox(
                color: Color(0xFF252532),
                child: Icon(Broken.user, color: Colors.white38),
              )
            : ExtendedImage.network(
                url!,
                fit: BoxFit.cover,
                cache: true,
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.completed) {
                    return null;
                  }
                  return const AppShimmerBlock(radius: 0);
                },
              ),
      ),
    );
  }
}

class _PersonMeta extends StatelessWidget {
  final String label;
  final String value;

  const _PersonMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        '$label • $value',
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }
}

class _PersonInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PersonInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _PersonTextCard extends StatelessWidget {
  final String text;

  const _PersonTextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, height: 1.55),
      ),
    );
  }
}

class _PeopleSectionTitle extends StatelessWidget {
  final String title;
  final int? count;

  const _PeopleSectionTitle({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (count != null)
          Text('$count', style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}

class _PeopleEmpty extends StatelessWidget {
  const _PeopleEmpty();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Aucune information disponible.',
      style: TextStyle(color: Colors.white54),
    );
  }
}

class _PeopleLoading extends StatelessWidget {
  const _PeopleLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, index) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: SizedBox(height: 66, child: AppShimmerBlock()),
      ),
    );
  }
}
