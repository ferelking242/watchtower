import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/endpoints.dart';
import '../functions/network.dart';
import '../functions/function.dart';
import '../models/custom_exceptions.dart';
import '../models/external_id_lookup.dart';
import '../models/tv.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/common/bookmark_screen.dart';
import '../screens/common/deep_link_loader.dart';
import '../screens/movie/collection_detail.dart';
import '../screens/movie/movie_detail.dart';
import '../screens/tv/episode_detail.dart';
import '../screens/tv/seasons_detail.dart';
import '../screens/tv/tv_detail.dart';
import '../screens/wellness/wellness_screen.dart';
import '../widgets/person_widgets.dart';
import 'home_widget_deep_link.dart';

/// Where a fetch reads from: the language it asks for, and the proxy it goes through.
typedef LinkSource = ({String language, bool useProxy, String proxy});

/// The screens a link can open, one route per kind of record.
///
/// Media links use a [DeepLinkLoader]; widgets prepare their routes before navigation. The
/// destination is the page the app would have built from its own lists, with the rating, the
/// votes and the synopsis the screens read off the record they are handed. A link carries an id and,
/// at best, a name and a picture — everything else is fetched here, before anything is built.
///
/// Home screen widgets, TMDB addresses and IMDb addresses all come through here, so a film opened any
/// of those ways arrives at the same screen with the same record behind it.
class DeepLinkRoutes {
  const DeepLinkRoutes._();

  /// Resolve widget data before navigation, including before runApp on a cold start.
  /// Failed requests retain the target and offer the same retry as other links.
  static Future<Route<void>> prepareWidget(
    HomeWidgetTarget target,
    LinkSource source,
  ) async {
    Future<Widget> load(LinkSource source) => switch (target) {
          HomeWidgetMovieTarget() => _moviePage(id: target.id, source: source),
          HomeWidgetTvTarget() => _tvPage(id: target.id, source: source),
          HomeWidgetEpisodeTarget() => _episodePage(
              seriesId: target.seriesId,
              seasonNumber: target.seasonNumber,
              episodeNumber: target.episodeNumber,
              seriesName: target.seriesName,
              posterPath: target.posterPath,
              source: source,
            ),
          HomeWidgetWellnessTarget() => Future.value(const WellnessScreen()),
          HomeWidgetMyListTarget() => Future.value(const BookmarkScreen()),
          HomeWidgetHomeTarget() => throw StateError('Home needs no route'),
        };
    try {
      if (target is HomeWidgetMovieTarget ||
          target is HomeWidgetTvTarget ||
          target is HomeWidgetEpisodeTarget) {
        if (!await checkConnection().timeout(const Duration(seconds: 3))) {
          throw const SocketException('No connection to fetch the record');
        }
      }
      final page = await load(source).timeout(const Duration(seconds: 12));
      return MaterialPageRoute<void>(builder: (_) => page);
    } catch (error) {
      return MaterialPageRoute<void>(
        builder: (_) => DeepLinkLoader(
          initialError: error,
          load: (context) => load(_source(context)),
        ),
      );
    }
  }

  static Route<void> movie({
    required int id,
    String? title,
    String? artworkPath,
  }) =>
      _route(
        title: title,
        artworkPath: artworkPath,
        load: (source) => _moviePage(id: id, source: source, title: title),
      );

  static Route<void> tv({
    required int id,
    String? name,
    String? artworkPath,
  }) =>
      _route(
        title: name,
        artworkPath: artworkPath,
        load: (source) => _tvPage(id: id, source: source),
      );

  static Route<void> season({
    required int seriesId,
    required int seasonNumber,
    String? seriesName,
    String? artworkPath,
  }) =>
      _route(
        title: seriesName,
        artworkPath: artworkPath,
        load: (source) => _seasonPage(
          seriesId: seriesId,
          seasonNumber: seasonNumber,
          source: source,
          seriesName: seriesName,
        ),
      );

  static Route<void> episode({
    required int seriesId,
    required int seasonNumber,
    required int episodeNumber,
    String? seriesName,
    String? displayTitle,
    String? posterPath,
    String? artworkPath,
  }) =>
      _route(
        title: displayTitle ?? seriesName,
        artworkPath: artworkPath ?? posterPath,
        load: (source) => _episodePage(
          seriesId: seriesId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          source: source,
          seriesName: seriesName,
          posterPath: posterPath,
        ),
      );

  static Route<void> person({
    required int id,
    String? name,
    String? profilePath,
  }) =>
      _route(
        title: name,
        artworkPath: profilePath,
        load: (source) => _personPage(
          id: id,
          source: source,
          name: name,
          profilePath: profilePath,
        ),
      );

  static Route<void> collection({
    required int id,
    String? name,
    String? artworkPath,
  }) =>
      _route(
        title: name,
        artworkPath: artworkPath,
        load: (source) => _collectionPage(id: id, source: source),
      );

  /// An IMDb title id, which stands for a film, a series, a season or one episode without saying
  /// which of those it is.
  ///
  /// TMDB is asked first, and its answer decides the screen. There is nothing to show behind the wait
  /// because until that answer comes back the app does not know what is being opened.
  ///
  /// [seasonNumber] is set when the link was IMDb's season view, which names the series and puts the
  /// season beside it; a series resolved from such a link opens on that season.
  static Route<void> imdbTitle({required String imdbId, int? seasonNumber}) =>
      _route(
        load: (source) async {
          final lookup = await _lookup(imdbId, source);
          return _imdbTitlePage(lookup, source, seasonNumber, imdbId);
        },
      );

  static Route<void> imdbName({required String imdbId}) => _route(
        load: (source) async {
          final person = (await _lookup(imdbId, source)).person;
          if (person == null) {
            throw NotFoundException(message: 'IMDb name $imdbId');
          }
          return _personPage(
            id: person.id,
            source: source,
            name: person.name,
            profilePath: person.profilePath,
          );
        },
      );

  static Route<void> wellness() => MaterialPageRoute<void>(
        builder: (_) => const WellnessScreen(),
      );

  static Route<void> myList() => MaterialPageRoute<void>(
        builder: (_) => const BookmarkScreen(),
      );

  // ---------------------------------------------------------------- the pages

  static Future<Widget> _moviePage({
    required int id,
    required LinkSource source,
    String? title,
  }) async {
    final movie = await getMovie(
      Endpoints.movieDetailsUrl(id, source.language),
      source.useProxy,
      source.proxy,
    );
    // A body that did not parse into a film leaves the page with nothing to render, so it is treated
    // as the absence it is instead of being shown.
    if (movie.id == null) {
      throw NotFoundException(message: 'movie $id');
    }
    return MovieDetailPage(movie: movie, heroId: _heroId('movie', id));
  }

  static Future<Widget> _tvPage({
    required int id,
    required LinkSource source,
  }) async {
    final show = await _series(id, source);
    return TVDetailPage(tvSeries: show, heroId: _heroId('tv', id));
  }

  /// One season of a series.
  ///
  /// The season screen is built out of the series record the season belongs to, so a link naming a
  /// season is answered by fetching the series and picking the season out of it.
  static Future<Widget> _seasonPage({
    required int seriesId,
    required int seasonNumber,
    required LinkSource source,
    String? seriesName,
  }) async {
    // The screen needs the series' seasons and, above them, the series' own name; those come from two
    // endpoints, so both are asked at once rather than one after the other.
    final detailsRequest = fetchTVDetails(
      Endpoints.getTVSeasons(seriesId, source.language),
      source.useProxy,
      source.proxy,
    );
    final seriesRequest = _series(seriesId, source);
    final details = await detailsRequest;
    final series = await seriesRequest;
    final season = _season(details, seasonNumber);
    // A season the series does not list cannot be opened as one, and the series it belongs to is the
    // closest thing to what the link asked for.
    if (season == null) {
      return TVDetailPage(tvSeries: series, heroId: _heroId('tv', seriesId));
    }
    return SeasonsDetail(
      seasons: season,
      tvDetails: details,
      tvId: seriesId,
      seriesName: series.name ?? seriesName,
      heroId: _heroId('season', seriesId, seasonNumber),
    );
  }

  static Future<Widget> _episodePage({
    required int seriesId,
    required int seasonNumber,
    required int episodeNumber,
    required LinkSource source,
    String? seriesName,
    String? posterPath,
  }) async {
    final episode = await getEpisode(
      Endpoints.getEpisodeDetails(
        seriesId,
        seasonNumber,
        episodeNumber,
        source.language,
      ),
      source.useProxy,
      source.proxy,
    );
    if (episode.episodeNumber == null || episode.seasonNumber == null) {
      throw NotFoundException(
        message: 'episode S${seasonNumber}E$episodeNumber of $seriesId',
      );
    }
    var poster = posterPath;
    var series = seriesName;
    // Playing and downloading an episode both need the series poster and name, and a link only
    // carries them when whatever sent it had them to give.
    if (poster == null || series == null) {
      final show = await _series(seriesId, source);
      poster ??= show.posterPath;
      series ??= show.name;
    }
    return EpisodeDetailPage(
      episodeList: episode,
      tvId: seriesId,
      seriesName: series,
      posterPath: poster,
    );
  }

  static Future<Widget> _personPage({
    required int id,
    required LinkSource source,
    String? name,
    String? profilePath,
  }) async {
    final person = await fetchPersonDetails(
      Endpoints.getPersonDetails(id, source.language),
      source.useProxy,
      source.proxy,
    );
    if (person.id == null) {
      throw NotFoundException(message: 'person $id');
    }
    // The record is also what decides whether this person is shown at all: the screen keeps adult
    // work from anyone who has not asked for it, and can only do that if it is told.
    return PersonDetailView(
      personId: person.id!,
      name: person.name ?? name ?? '',
      subtitle: person.department,
      profilePath: person.profilePath ?? profilePath,
      isPersonAdult: person.isAdult,
      heroId: _heroId('person', id),
    );
  }

  static Future<Widget> _collectionPage({
    required int id,
    required LinkSource source,
  }) async {
    // The collection screen is written for a collection named by one of its films. Reached from a
    // link there is no film, so the collection's own record stands in for it.
    final collection = await fetchCollectionSummary(
      Endpoints.getCollectionDetails(id, source.language),
      source.useProxy,
      source.proxy,
    );
    if (collection.id == null) {
      throw NotFoundException(message: 'collection $id');
    }
    return CollectionDetailsWidget(belongsToCollection: collection);
  }

  /// The screen for whatever TMDB says an IMDb title id is, most specific match first.
  static Future<Widget> _imdbTitlePage(
    ExternalIdLookup lookup,
    LinkSource source,
    int? seasonNumber,
    String imdbId,
  ) {
    final episode = lookup.episode;
    if (episode != null) {
      return _episodePage(
        seriesId: episode.seriesId,
        seasonNumber: episode.seasonNumber,
        episodeNumber: episode.episodeNumber,
        source: source,
      );
    }
    final season = lookup.season;
    if (season != null) {
      return _seasonPage(
        seriesId: season.seriesId,
        seasonNumber: season.seasonNumber,
        source: source,
      );
    }
    final movie = lookup.movie;
    if (movie != null) {
      return _moviePage(id: movie.id, source: source, title: movie.title);
    }
    final series = lookup.tv;
    if (series != null) {
      return seasonNumber == null
          ? _tvPage(id: series.id, source: source)
          : _seasonPage(
              seriesId: series.id,
              seasonNumber: seasonNumber,
              source: source,
              seriesName: series.title,
            );
    }
    final person = lookup.person;
    if (person != null) {
      return _personPage(
        id: person.id,
        source: source,
        name: person.name,
        profilePath: person.profilePath,
      );
    }
    // IMDb holds titles TMDB has never had, so an empty answer is an answer.
    throw NotFoundException(message: 'IMDb title $imdbId');
  }

  // ------------------------------------------------------------- the plumbing

  static Route<void> _route({
    required Future<Widget> Function(LinkSource source) load,
    String? title,
    String? artworkPath,
  }) =>
      MaterialPageRoute<void>(
        builder: (_) => DeepLinkLoader(
          title: title,
          artworkPath: artworkPath,
          load: (context) => load(_source(context)),
        ),
      );

  static Future<ExternalIdLookup> _lookup(
    String imdbId,
    LinkSource source,
  ) =>
      findByExternalId(
        Endpoints.findByExternalId(imdbId, 'imdb_id', source.language),
        source.useProxy,
        source.proxy,
      );

  static Future<TV> _series(int id, LinkSource source) async {
    final show = await getTV(
      Endpoints.tvDetailsUrl(id, source.language),
      source.useProxy,
      source.proxy,
    );
    if (show.id == null) {
      throw NotFoundException(message: 'TV series $id');
    }
    return show;
  }

  static Seasons? _season(TVDetails details, int seasonNumber) {
    for (final season in details.seasons ?? const <Seasons>[]) {
      if (season.seasonNumber == seasonNumber) return season;
    }
    return null;
  }

  /// A tag for the artwork the page flies in, unique to what is being opened.
  static String _heroId(String kind, int id, [int? part]) =>
      part == null ? 'deep-link-$kind-$id' : 'deep-link-$kind-$id-$part';

  /// Read before the first await, so a fetch is never holding on to a context.
  static LinkSource _source(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dependencies = Provider.of<AppDependencyProvider>(
      context,
      listen: false,
    );
    return (
      language: settings.appLanguage,
      useProxy: settings.enableProxy,
      proxy: dependencies.tmdbProxy,
    );
  }
}
