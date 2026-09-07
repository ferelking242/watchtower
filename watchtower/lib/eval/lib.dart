import 'package:watchtower/eval/interface.dart';
  import 'package:watchtower/models/source.dart';

  import 'dart/service.dart';
  import 'javascript/service.dart';
  import 'mihon/service.dart';

  ExtensionService getExtensionService(Source source, String androidProxyServer) {
    return switch (source.sourceCodeLanguage) {
      SourceCodeLanguage.dart => DartExtensionService(source),
      SourceCodeLanguage.javascript => JsExtensionService(source),
      SourceCodeLanguage.mihon => MihonExtensionService(source, androidProxyServer),
    };
  }

  /// Caches one [ExtensionService] per source, preventing repeated create/
  /// destroy cycles that cause QuickJS gc_obj_list assertion crashes when
  /// multiple sources initialise concurrently (e.g. home page with many tiles).
  class ExtensionServiceRegistry {
    static final _cache = <String, ExtensionService>{};

    static String _key(Source source) =>
        (source.id ?? source.name ?? source.hashCode.toString()).toString();

    /// Returns the cached service for [source], creating one if needed.
    static ExtensionService get(Source source, String proxyServer) {
      return _cache.putIfAbsent(
        _key(source),
        () => getExtensionService(source, proxyServer),
      );
    }

    /// Disposes and removes the service for a single source (e.g. on uninstall).
    static void disposeSource(String sourceId) {
      final svc = _cache.remove(sourceId);
      if (svc != null) {
        try { svc.dispose(); } catch (_) {}
      }
    }

    /// Disposes all cached services (call on app exit or full reload).
    static void disposeAll() {
      for (final svc in _cache.values) {
        try { svc.dispose(); } catch (_) {}
      }
      _cache.clear();
    }
  }

  /// Returns the cached [ExtensionService] for [source] via
  /// [ExtensionServiceRegistry].  The service is intentionally NOT disposed
  /// after each call — it is reused to avoid concurrent QuickJS runtime crashes.
  Future<T> withExtensionService<T>(
    Source source,
    String proxyServer,
    Future<T> Function(ExtensionService service) action,
  ) async {
    final service = ExtensionServiceRegistry.get(source, proxyServer);
    return action(service);
  }
  