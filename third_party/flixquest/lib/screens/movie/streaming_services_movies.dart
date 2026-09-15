import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '/provider/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/api/endpoints.dart';
import '/widgets/movie_widgets.dart';
import '/provider/app_dependency_provider.dart';
import '/video_providers/scraper_api.dart';
import '/widgets/hosted_ads_banner.dart';

class StreamingServicesMovies extends StatelessWidget {
  final int providerId;
  final String providerName;
  const StreamingServicesMovies(
      {super.key, required this.providerId, required this.providerName});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('streaming_service_movie', namedArgs: {'provider': providerName}),
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
            placement: 'streaming_movies',
            loadAds: () => ScraperApi(
              context.read<AppDependencyProvider>().flixquestAPIURL,
            ).getAds(),
          ),
          Expanded(
            child: ParticularStreamingServiceMovies(
              includeAdult: Provider.of<SettingsProvider>(context).isAdult,
              providerID: providerId,
              api: Endpoints.watchProvidersMovies(providerId, 1, lang),
              watchRegion: 'US',
            ),
          ),
        ],
      ),
    );
  }
}
