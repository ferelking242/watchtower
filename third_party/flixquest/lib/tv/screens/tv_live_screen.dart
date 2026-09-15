import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../controllers/live_tv_database_controller.dart';
import '../../functions/function.dart';
import '../../models/live_tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/live_player.dart';
import '../../services/analytics_service.dart';
import '../../services/daddylive_service.dart';
// EthioTV source (commented out - disabled):
// import '../../services/ethio_sports_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../player/tv_player_screen.dart';
import '../widgets/tv_state_panel.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_dialog.dart';

enum _TvLiveScope { all, favorites, recent }

enum _TvLiveMode { channels, schedule }

// EthioTV source (commented out - disabled):
// enum _TvLiveSource { daddyLive, ethioSports }

class TvLiveScreen extends StatefulWidget {
  const TvLiveScreen({required this.metrics, this.focusController, super.key});

  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;

  @override
  State<TvLiveScreen> createState() => _TvLiveScreenState();
}

class _TvLiveScreenState extends State<TvLiveScreen> {
  static const _analyticsSurface = 'tv';
  final _daddyDatabase = LiveTVDatabaseController();
  // EthioTV source (commented out - disabled):
  // final _ethioDatabase = LiveTVDatabaseController(namespace: 'ethiosports');
  final _searchController = TextEditingController();
  late final FocusNode _searchFocus;
  final _channelGrid = TvContentGridController();
  final _browseFocus = FocusNode(debugLabel: 'Live TV browse controls');
  bool _showSearch = false;
  DaddyLiveService? _service;
  // EthioTV source (commented out - disabled):
  // EthioSportsService? _ethioService;
  List<Channel> _channels = const <Channel>[];
  DaddyLiveEpg? _epg;
  Set<String> _favorites = <String>{};
  List<String> _recent = const <String>[];
  _TvLiveScope _scope = _TvLiveScope.all;
  _TvLiveMode _mode = _TvLiveMode.channels;
  // EthioTV source (commented out - disabled):
  // _TvLiveSource _source = _TvLiveSource.daddyLive;
  String? _category;
  int _selectedDayIndex = 0;
  String? _resolvingId;
  String _query = '';
  String? _error;
  bool _loading = true;
  bool _initialChannelFocusRequested = false;
  Timer? _searchAnalyticsDebounce;

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _requestContentFocus);
    _searchFocus = FocusNode(
      debugLabel: 'Live TV search',
      onKeyEvent: _handleSearchKeyEvent,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analytics.trackLiveTVScreenOpened(surface: _analyticsSurface);
      _load();
    });
  }

  void _requestContentFocus() {
    if (_mode == _TvLiveMode.channels && _visible.isNotEmpty) {
      _channelGrid.requestFocus();
    } else if (_browseFocus.context != null) {
      _browseFocus.requestFocus();
    }
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    return node.focusInDirection(direction)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(TvLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _requestContentFocus);
    }
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _searchAnalyticsDebounce?.cancel();
    _service?.close();
    // EthioTV source (commented out - disabled):
    // _ethioService?.close();
    _searchController.dispose();
    _searchFocus.dispose();
    _browseFocus.dispose();
    super.dispose();
  }

  DaddyLiveService _api() => _service ??= DaddyLiveService(
        baseUrl: context.read<AppDependencyProvider>().flixquestAPIURL,
      );

  // EthioTV source (commented out - disabled):
  // EthioSportsService _ethioApi() => _ethioService ??= EthioSportsService(
  //       baseUrl: context.read<AppDependencyProvider>().flixquestAPIURLV2,
  //     );
  //
  // LiveTvService get _activeService =>
  //     _source == _TvLiveSource.ethioSports ? _ethioApi() : _api();
  //
  // LiveTVDatabaseController get _database =>
  //     _source == _TvLiveSource.ethioSports ? _ethioDatabase : _daddyDatabase;

  AnalyticsService get _analytics => context.read<SettingsProvider>().analytics;

  Future<void> _load({bool refresh = false}) async {
    final stopwatch = Stopwatch()..start();
    var cacheHit = false;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final favorites = await _daddyDatabase.getFavoriteIds();
      final recent = await _daddyDatabase.getRecentIds();
      List<Channel> channels;
      DaddyLiveEpg? epg;
      if (!refresh && await _daddyDatabase.isCacheValid()) {
        cacheHit = true;
        channels = await _daddyDatabase.getCachedChannels();
        epg = await _daddyDatabase.getCachedEpg();
      } else {
        final catalog = await _api().getCatalog(refresh: refresh);
        channels = catalog.channels;
        epg = catalog.epg;
        await _daddyDatabase.cacheChannels(channels);
        await _daddyDatabase.cacheEpg(epg);
      }
      channels = channels.toList()..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _epg = epg;
        _favorites = favorites;
        _recent = recent;
        _loading = false;
      });
      _focusInitialChannelResult();
      _analytics.trackLiveTVCatalogLoad(
        surface: _analyticsSurface,
        refresh: refresh,
        cacheHit: cacheHit,
        success: true,
        durationMs: stopwatch.elapsedMilliseconds,
        channelCount: channels.length,
        epgDayCount: epg?.days.length ?? 0,
      );
    } catch (error) {
      final cached = await _daddyDatabase.getCachedChannels();
      final cachedEpg = await _daddyDatabase.getCachedEpg();
      if (!mounted) return;
      setState(() {
        _channels = cached;
        _epg = cachedEpg;
        _loading = false;
        _error = cached.isEmpty ? friendlyLiveTvError(error) : null;
      });
      _focusInitialChannelResult();
      _analytics.trackLiveTVCatalogLoad(
        surface: _analyticsSurface,
        refresh: refresh,
        cacheHit: cacheHit,
        success: false,
        fallbackToCache: cached.isNotEmpty,
        durationMs: stopwatch.elapsedMilliseconds,
        channelCount: cached.length,
        epgDayCount: cachedEpg?.days.length ?? 0,
        error: error.toString(),
      );
    }
  }

  List<String> get _categories {
    final categories = _channels.expand((item) => item.categories).toSet();
    return categories.toList()..sort();
  }

  List<Channel> get _visible {
    Iterable<Channel> result = _channels;
    if (_scope == _TvLiveScope.favorites) {
      result = result.where((item) => _favorites.contains(item.id));
    } else if (_scope == _TvLiveScope.recent) {
      final byId = <String, Channel>{for (final item in result) item.id: item};
      result = _recent.map((id) => byId[id]).whereType<Channel>();
    }
    if (_category != null) {
      result = result.where((item) => item.categories.contains(_category));
    }
    final tokens = searchTokens(_query);
    if (tokens.isNotEmpty) {
      result = result.where((item) => _matches(item, tokens));
    }
    return result.toList(growable: false);
  }

  static bool _matches(Channel channel, List<String> tokens) {
    // 24/7 channels match by their own identity only (name / id), never by
    // the event that happens to be airing. Use the Schedule search for teams.
    final haystack = normalizeSearchText('${channel.name} ${channel.id}');
    return tokens.every(haystack.contains);
  }

  static bool _eventMatches(
    DaddyLiveEpgEvent event,
    String categoryName,
    List<String> tokens,
  ) {
    final haystack = normalizeSearchText(
      '$categoryName ${event.title} '
      '${event.channels.map((channel) => channel.name).join(' ')}',
    );
    return tokens.every(haystack.contains);
  }

  List<({String name, List<DaddyLiveEpgEvent> events})> get _scheduleSections {
    final epg = _epg;
    if (epg == null || epg.days.isEmpty) return const [];
    final day = epg.days[_selectedDayIndex.clamp(0, epg.days.length - 1)];
    final tokens = searchTokens(_query);
    return <({String name, List<DaddyLiveEpgEvent> events})>[
      for (final category in day.categories)
        (
          name: category.name,
          events: category.events
              .where(
                (event) =>
                    tokens.isEmpty ||
                    _eventMatches(event, category.name, tokens),
              )
              .toList(growable: false),
        ),
    ]..removeWhere((section) => section.events.isEmpty);
  }

  int get _visibleEventCount =>
      _scheduleSections.fold(0, (sum, section) => sum + section.events.length);

  Future<void> _toggleFavorite(Channel channel) async {
    final value = await _daddyDatabase.toggleFavorite(channel.id);
    if (!mounted) return;
    setState(() {
      if (value) {
        _favorites.add(channel.id);
      } else {
        _favorites.remove(channel.id);
      }
    });
    _analytics.trackLiveTVFavorite(
      surface: _analyticsSurface,
      channelId: channel.id,
      channelName: channel.name,
      added: value,
    );
  }

  Future<void> _play(Channel channel) async {
    final stopwatch = Stopwatch()..start();
    setState(() => _resolvingId = channel.id);
    try {
      final stream = await _api().getStream(channel.id);
      await _daddyDatabase.addRecent(channel.id);
      if (!mounted) return;
      _analytics.trackLiveTVChannelView(
        channelName: channel.name,
        streamId: channel.id,
      );
      _analytics.trackLiveTVStreamResolution(
        surface: _analyticsSurface,
        channelId: channel.id,
        channelName: channel.name,
        outcome: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
        source: _mode.name,
      );
      final theme = Theme.of(context);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TvPlayerScreen(
            child: LivePlayer(
              channelName: channel.name,
              videoUrl: stream.url,
              headers: stream.headers,
              mediaType: stream.mediaType,
              clearKey: stream.clearKey,
              variants: stream.variants,
              autoFullScreen: false,
              colors: <Color>[
                theme.colorScheme.primary,
                Colors.black,
              ],
              // Keep in-player switching independent from browse filters.
              channels: _channels,
              initialChannelId: channel.id,
              service: _api(),
              analytics: _analytics,
              analyticsSurface: _analyticsSurface,
              scraperApiUrl:
                  context.read<AppDependencyProvider>().flixquestAPIURL,
              onChannelSwitch: (switched) =>
                  _daddyDatabase.addRecent(switched.id),
              enableCast: false,
              useTvControls: true,
            ),
          ),
        ),
      );
      _recent = await _daddyDatabase.getRecentIds();
      if (mounted) setState(() {});
    } catch (error) {
      _analytics.trackLiveTVStreamResolution(
        surface: _analyticsSurface,
        channelId: channel.id,
        channelName: channel.name,
        outcome: 'error',
        durationMs: stopwatch.elapsedMilliseconds,
        source: _mode.name,
        error: error.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyLiveTvError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchAnalyticsDebounce?.cancel();
    _searchAnalyticsDebounce = Timer(const Duration(milliseconds: 750), () {
      if (!mounted || value != _query) return;
      _analytics.trackLiveTVInteraction(
        surface: _analyticsSurface,
        action: 'search',
        value: _mode.name,
        resultCount: _mode == _TvLiveMode.channels
            ? _visible.length
            : _visibleEventCount,
      );
    });
  }

  void _focusInitialChannelResult() {
    if (_initialChannelFocusRequested || _visible.isEmpty) return;
    _initialChannelFocusRequested = true;
    _focusFirstChannelResult();
  }

  void _focusFirstChannelResult() {
    if (_mode != _TvLiveMode.channels || _visible.isEmpty) return;
    _channelGrid.requestFocus();
  }

  void _selectMode(_TvLiveMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'view_changed',
      value: mode.name,
    );
  }

  // EthioTV source (commented out - disabled):
  // void _selectSource(_TvLiveSource source) {
  //   if (source == _source) return;
  //   setState(() {
  //     _source = source;
  //     _mode = _TvLiveMode.channels;
  //     _category = null;
  //     _selectedDayIndex = 0;
  //     _channels = const <Channel>[];
  //     _epg = null;
  //     _initialChannelFocusRequested = false;
  //   });
  //   _load();
  // }

  void _selectScope(_TvLiveScope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'collection_changed',
      value: scope.name,
      resultCount: _visible.length,
    );
  }

  void _selectCategory(String? category) {
    if (category == _category) return;
    setState(() => _category = category);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'category_changed',
      value: category ?? 'all',
      resultCount: _visible.length,
    );
  }

  void _selectDay(int index) {
    if (index == _selectedDayIndex) return;
    setState(() => _selectedDayIndex = index);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'schedule_day_changed',
      value: _epg?.days[index].label,
      resultCount: _visibleEventCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return _buildError();
    final isSchedule = _mode == _TvLiveMode.schedule;
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.metrics.contentPadding,
          0,
          widget.metrics.contentPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildTitle(isSchedule),
            const SizedBox(height: 6),
            _buildControls(isSchedule),
            if (!isSchedule && _categories.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              _buildCategories(),
            ],
            if (isSchedule &&
                _epg != null &&
                _epg!.days.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              _buildDays(),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: isSchedule ? _buildSchedule() : _buildGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(bool isSchedule) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 48,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isSchedule
                ? PhosphorIcons.calendarDots()
                : PhosphorIcons.broadcast(),
            color: colors.primary,
            size: 27,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isSchedule ? 'Schedule' : 'Live TV',
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: 'FigtreeSB',
                  fontSize: 28,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isSchedule
                    ? '$_visibleEventCount events • Select a match to watch'
                    : '${_visible.length} channels • Hold OK for favorites',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        TvFocusable(
          focusNode: _browseFocus,
          semanticLabel: 'Search channels',
          selected: _showSearch,
          onActivate: () {
            setState(() => _showSearch = !_showSearch);
            if (_showSearch) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _searchFocus.requestFocus();
              });
            }
          },
          child:
              _TvPill(icon: PhosphorIcons.magnifyingGlass(), label: 'Search'),
        ),
        const SizedBox(width: 10),
        TvFocusable(
          semanticLabel: 'Refresh live TV',
          onActivate: () => _load(refresh: true),
          focusScale: 1.025,
          child: _TvPill(
            icon: PhosphorIcons.arrowsClockwise(),
            label: 'Refresh',
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isSchedule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // EthioTV source (commented out - disabled):
        // _TvSegmentedTrack(
        //   fill: true,
        //   options: <_TvSegmentedOption>[
        //     _TvSegmentedOption(
        //       icon: PhosphorIcons.broadcast(),
        //       label: 'DaddyLive',
        //       semanticLabel: 'DaddyLive source',
        //       selected: _source == _TvLiveSource.daddyLive,
        //       onActivate: () => _selectSource(_TvLiveSource.daddyLive),
        //     ),
        //     _TvSegmentedOption(
        //       icon: PhosphorIcons.football(),
        //       label: 'Ethio Sports',
        //       semanticLabel: 'Ethio Sports source',
        //       selected: _source == _TvLiveSource.ethioSports,
        //       onActivate: () => _selectSource(_TvLiveSource.ethioSports),
        //     ),
        //   ],
        // ),
        // const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: Row(
            children: <Widget>[
              _TvSegmentedTrack(
                options: <_TvSegmentedOption>[
                  _TvSegmentedOption(
                    icon: PhosphorIcons.televisionSimple(),
                    label: 'Channels',
                    semanticLabel: 'Channels view',
                    selected: _mode == _TvLiveMode.channels,
                    onActivate: () => _selectMode(_TvLiveMode.channels),
                  ),
                  _TvSegmentedOption(
                    icon: PhosphorIcons.calendarDots(),
                    label: 'Schedule',
                    semanticLabel: 'Schedule view',
                    selected: _mode == _TvLiveMode.schedule,
                    onActivate: () => _selectMode(_TvLiveMode.schedule),
                  ),
                ],
              ),
              if (!isSchedule) ...<Widget>[
                const SizedBox(width: 14),
                _TvSegmentedTrack(
                  options: <_TvSegmentedOption>[
                    _TvSegmentedOption(
                      icon: PhosphorIcons.broadcast(),
                      label: 'All',
                      semanticLabel: 'All channels',
                      selected: _scope == _TvLiveScope.all,
                      onActivate: () => _selectScope(_TvLiveScope.all),
                    ),
                    _TvSegmentedOption(
                      icon: PhosphorIcons.heart(),
                      label: 'Favorites',
                      semanticLabel: 'Favorites channels',
                      selected: _scope == _TvLiveScope.favorites,
                      onActivate: () => _selectScope(_TvLiveScope.favorites),
                    ),
                    _TvSegmentedOption(
                      icon: PhosphorIcons.clockCounterClockwise(),
                      label: 'Recent',
                      semanticLabel: 'Recent channels',
                      selected: _scope == _TvLiveScope.recent,
                      onActivate: () => _selectScope(_TvLiveScope.recent),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_showSearch) ...<Widget>[
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _focusFirstChannelResult(),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
              ),
              decoration: InputDecoration(
                hintText: isSchedule
                    ? 'Search matches, teams & leagues'
                    : 'Search channels',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          _searchFocus.requestFocus();
                        },
                        icon: Icon(PhosphorIcons.x()),
                      ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          TvFocusable(
            semanticLabel: 'All categories',
            selected: _category == null,
            onActivate: () => _selectCategory(null),
            focusScale: 1.025,
            child:
                _TvPill(label: 'All categories', selected: _category == null),
          ),
          for (final category in _categories) ...<Widget>[
            const SizedBox(width: 8),
            TvFocusable(
              semanticLabel: '$category category',
              selected: _category == category,
              onActivate: () => _selectCategory(category),
              focusScale: 1.025,
              child: _TvPill(
                label: category,
                selected: _category == category,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDays() {
    final days = _epg!.days;
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (var i = 0; i < days.length; i++) ...<Widget>[
            if (i != 0) const SizedBox(width: 8),
            TvFocusable(
              semanticLabel: '${_prettyDayLabel(days[i].label)} schedule',
              selected: _selectedDayIndex == i,
              onActivate: () => _selectDay(i),
              focusScale: 1.025,
              child: _TvPill(
                label: _prettyDayLabel(days[i].label),
                selected: _selectedDayIndex == i,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _prettyDayLabel(String label) {
    final parsed = DateTime.tryParse(label);
    if (parsed == null) return label;
    return DateFormat('EEE, MMM d').format(parsed);
  }

  Widget _buildGrid() {
    final channels = _visible;
    if (channels.isEmpty) {
      return TvStatePanel(
        title: 'No channels found',
        message: 'Try another search, category, or collection.',
        icon: PhosphorIcons.televisionSimple(),
      );
    }
    return TvContentGrid<Channel>(
      controller: _channelGrid,
      scopeId: 'live-${_scope.name}-${_category ?? 'all'}-$_query',
      items: channels,
      itemId: (channel) => channel.id,
      semanticLabel: (channel) =>
          'Watch ${channel.name}. Hold OK for favorites.',
      targetItemWidth: widget.metrics.compact ? 210 : 280,
      itemExtent: 126,
      horizontalSpacing: 12,
      verticalSpacing: 12,
      onItemActivated: (channel) {
        if (_resolvingId == null) _play(channel);
      },
      onItemMenu: (channel) => showTvDialog<void>(
        context: context,
        title: channel.name,
        content: const Text('Channel options'),
        actions: [
          TvDialogAction(
            label: _favorites.contains(channel.id)
                ? 'Remove from favorites'
                : 'Add to favorites',
            onPressed: () {
              Navigator.of(context).pop();
              _toggleFavorite(channel);
            },
          ),
          TvDialogAction(
              label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      itemBuilder: (_, channel, width) => _TvChannelCard(
        channel: channel,
        favorite: _favorites.contains(channel.id),
        resolving: _resolvingId == channel.id,
      ),
    );
  }

  Widget _buildSchedule() {
    final sections = _scheduleSections;
    if (sections.isEmpty) {
      return TvStatePanel(
        title: _epg?.days.isNotEmpty ?? false
            ? 'No matches found'
            : 'Schedule unavailable',
        message: _epg?.days.isNotEmpty ?? false
            ? 'Try another team, league, or day.'
            : "Refresh to load today's schedule.",
        icon: PhosphorIcons.calendarDots(),
        actionLabel: (_epg?.days.isNotEmpty ?? false) ? null : 'Refresh',
        onAction: (_epg?.days.isNotEmpty ?? false)
            ? null
            : () => _load(refresh: true),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(3, 3, 12, 30),
      itemCount: sections.length,
      itemBuilder: (_, sectionIndex) {
        final section = sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'FigtreeSB',
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Text(
                    '${section.events.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            for (final event in section.events) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TvScheduleEventTile(
                  event: event,
                  resolvingChannelId: _resolvingId,
                  onPlay: _play,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildError() {
    return TvStatePanel.error(
      onRetry: _load,
      message: _error ?? 'Live TV is currently unavailable.',
    );
  }
}

class _TvSegmentedOption {
  const _TvSegmentedOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onActivate,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback onActivate;
}

class _TvSegmentedTrack extends StatelessWidget {
  // EthioTV source (commented out - disabled): full-width `fill: true` tracks
  // were only used by the Ethio source selector.
  const _TvSegmentedTrack({required this.options});

  final List<_TvSegmentedOption> options;

  // EthioTV source (commented out - disabled):
  // final bool fill;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cells = <Widget>[
      for (var index = 0; index < options.length; index++)
        Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
          child: TvFocusable(
            semanticLabel: options[index].semanticLabel ?? options[index].label,
            selected: options[index].selected,
            onActivate: options[index].onActivate,
            focusScale: 1.03,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: _TvSegmentCell(
              icon: options[index].icon,
              label: options[index].label,
              selected: options[index].selected,
            ),
          ),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: cells),
    );
  }
}

class _TvSegmentCell extends StatelessWidget {
  const _TvSegmentCell({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: 21,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontFamily: selected ? 'FigtreeSB' : 'Figtree',
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _TvPill extends StatelessWidget {
  const _TvPill({required this.label, this.icon, this.selected = false});

  final String label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.18)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: colors.primary.withValues(alpha: 0.4))
            : Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 22,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            if (label.isNotEmpty) const SizedBox(width: 8),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontFamily: selected ? 'FigtreeSB' : 'Figtree',
                fontSize: 17,
              ),
            ),
        ],
      ),
    );
  }
}

class _TvScheduleEventTile extends StatelessWidget {
  const _TvScheduleEventTile({
    required this.event,
    required this.resolvingChannelId,
    required this.onPlay,
  });

  final DaddyLiveEpgEvent event;
  final String? resolvingChannelId;
  final void Function(Channel channel) onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TvDesign.surfaceFor(context, emphasis: 0.04),
        borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              constraints: const BoxConstraints(minWidth: 76),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                event.displayTime,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.primary,
                  fontFamily: 'FigtreeSB',
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'FigtreeSB',
                      fontSize: 20,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      for (final channel in event.channels)
                        TvFocusable(
                          semanticLabel: 'Watch on ${channel.name}',
                          enabled: resolvingChannelId != channel.id,
                          onActivate: () => onPlay(channel),
                          focusScale: 1.025,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10)),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (resolvingChannelId == channel.id)
                                  SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  )
                                else
                                  Icon(
                                    PhosphorIcons.broadcast(
                                      PhosphorIconsStyle.fill,
                                    ),
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  channel.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontFamily: 'FigtreeSB',
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvChannelCard extends StatelessWidget {
  const _TvChannelCard(
      {required this.channel, required this.favorite, required this.resolving});
  final Channel channel;
  final bool favorite;
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TvDesign.raisedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _TvChannelAvatar(name: channel.name, letter: channel.letter),
            const SizedBox(width: 10),
            Expanded(
                child: Text(channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.1))),
            if (favorite)
              Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill),
                  size: 18, color: colors.primary),
          ]),
          const Spacer(),
          Text(
              resolving
                  ? 'Opening channel…'
                  : channel.nowPlaying ??
                      channel.nextUp ??
                      'Channel ${channel.id} • OK to watch',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: TvDesign.mutedText, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TvChannelAvatar extends StatelessWidget {
  const _TvChannelAvatar({required this.name, this.letter});

  final String name;
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = (letter ?? (name.isEmpty ? '?' : name.trim()))
        .characters
        .first
        .toUpperCase();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primary.withValues(alpha: .85),
            colors.primary.withValues(alpha: .45),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onPrimary,
          fontFamily: 'FigtreeSB',
          fontSize: 17,
          height: 1,
        ),
      ),
    );
  }
}
