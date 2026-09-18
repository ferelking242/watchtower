import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/api/endpoints.dart';
import '/widgets/movie_widgets.dart';
import '/models/genres.dart';
import '/provider/app_dependency_provider.dart';
import '/video_providers/scraper_api.dart';
import '/widgets/hosted_ads_banner.dart';

class GenreMovies extends StatelessWidget {
  final Genres genres;
  const GenreMovies({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.analytics.trackGenreClicked(
      genreName: genres.genreName ?? 'Unknown',
      mediaType: 'Movie',
    );
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('genre_movie_title', namedArgs: {'g': genres.genreName ?? 'Null'}),
        ),
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          RemoteHostedAdsBanner(
            placement: 'genre_movies',
            loadAds: () => ScraperApi(
              context.read<AppDependencyProvider>().flixquestAPIURL,
            ).getAds(),
          ),
          Expanded(
            child: ParticularGenreMovies(
              includeAdult: Provider.of<SettingsProvider>(context).isAdult,
              genreId: genres.genreID!,
              api: Endpoints.getMoviesForGenre(genres.genreID!, 1, lang),
              watchRegion:
                  Provider.of<SettingsProvider>(context).defaultCountry,
            ),
          ),
        ],
      ),
    );
  }
}
