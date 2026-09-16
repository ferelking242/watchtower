// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String TMDB_API_BASE_URL = 'https://api.themoviedb.org/3';
String? _remoteTmdbApiKey;

/// Reads [key] from the loaded dotenv configuration, falling back to
/// [fallback] when the `.env` asset was never loaded.
///
/// [DotEnv.env] throws [NotInitializedError] before `dotenv.load()` runs.
/// Watchtower embeds FlixQuest screens without executing FlixQuest's
/// `main.dart`, so the embedded host must be able to read every config
/// constant before (and without) loading a `.env` file.
String? safeDotenv(String key, {String? fallback}) {
  try {
    return dotenv.env[key] ?? fallback;
  } catch (error) {
    // dotenv not initialized yet (or at all). Defaults keep the embedded
    // screens usable; a later successful load() picks the file back up.
    debugPrint('dotenv not initialized for "$key" — using fallback: $error');
    return fallback;
  }
}

/// The TMDB API key used across all metadata and search endpoints.
///
/// Initially falls back to `dotenv.env['TMDB_API_KEY']` (from the local `.env`).
/// If a non-empty key is fetched from Firebase Remote Config (`tmdb_api_key`),
/// it overrides this value at runtime.
String get TMDB_API_KEY => _remoteTmdbApiKey ?? safeDotenv('TMDB_API_KEY') ?? '';

set TMDB_API_KEY(String value) {
  final trimmed = value.trim();
  _remoteTmdbApiKey = trimmed.isNotEmpty ? trimmed : null;
}
String mixpanelKey = safeDotenv('MIXPANEL_API_KEY') ?? '';
const TMDB_BASE_IMAGE_URL = 'https://image.tmdb.org/t/p/';
const String EMBED_BASE_MOVIE_URL =
    'https://www.2embed.to/embed/tmdb/movie?id=';
const String EMBED_BASE_TV_URL =
    'https://www.2embed.to/embed/tmdb/tv?id=';
const String YOUTUBE_THUMBNAIL_URL = 'https://i3.ytimg.com/vi/';
const String YOUTUBE_BASE_URL = 'https://youtube.com/watch?v=';
const String FACEBOOK_BASE_URL = 'https://facebook.com/';
const String INSTAGRAM_BASE_URL = 'https://instagram.com/';
const String TWITTER_BASE_URL = 'https://twitter.com/';
const String IMDB_BASE_URL = 'https://imdb.com/title/';
const String TWOEMBED_BASE_URL = 'https://2embed.biz';
String flixquestApiUrl = safeDotenv('FLIXQUEST_API_URL') ?? '';
