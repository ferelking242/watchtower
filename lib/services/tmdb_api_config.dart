/// Shared TMDB configuration for discovery and local-library metadata lookup.
const tmdbApiBase = 'https://api.themoviedb.org/3';
const tmdbReadToken = String.fromEnvironment('TMDB_READ_TOKEN');

const tmdbApiHeaders = <String, String>{
  'Authorization': 'Bearer $tmdbReadToken',
  'Accept': 'application/json',
};