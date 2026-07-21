import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/isolate_service.dart';

/// Provider returning autocomplete suggestions from the extension's
/// getSuggestions(query) method.  Uses FutureProvider.family so Riverpod
/// caches one result per (source, query) pair without needing codegen.
final getSuggestionsProvider =
    FutureProvider.autoDispose.family<List<String>, (Source, String)>(
  (ref, args) async {
    final (source, query) = args;
    if (query.trim().length < 2) return [];
    try {
      final result = await getIsolateService.get<dynamic>(
        query: query,
        source: source,
        serviceType: 'getSuggestions',
        proxyServer: ref.read(androidProxyServerStateProvider),
      );
      if (result is List) return result.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  },
);
