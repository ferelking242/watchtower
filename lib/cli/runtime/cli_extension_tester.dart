import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:watchtower/cli/commands/meta_commands.dart' show cliVersion;
import 'package:watchtower/cli/runtime/cli_extension_catalog.dart';
import 'package:watchtower/cli/watchtower_cli_safety.dart';
import 'package:watchtower/eval/interface.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/services/isolate_service.dart';

/// Runs the real extension engine against a local repository, producing the
/// same per-step report the pre-refactor CLI emitted. Used by
/// `extensions test` and validated by the Linux headless workflow.

class CliExtensionTestStep {
  CliExtensionTestStep({
    required this.ok,
    required this.ms,
    this.count,
    this.error,
    this.errorType,
    this.extra,
  });

  final bool ok;
  final int ms;
  final int? count;
  final String? error;
  final String? errorType;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'status': ok ? 'passed' : 'failed',
    'ms': ms,
    'count': ?count,
    'error': ?error,
    'errorType': ?errorType,
    ...?extra,
  };
}

class CliExtensionTestResult {
  CliExtensionTestResult(this.item);

  final CliExtension item;
  final Map<String, CliExtensionTestStep> steps = {};
  bool ok = true;
  int totalMs = 0;

  Map<String, dynamic> toJson() => {
    'id': item.source.id,
    'name': item.source.name,
    'lang': item.source.lang,
    'itemType': item.source.itemType.name,
    'engine': item.source.sourceCodeLanguage.name,
    'file': item.file,
    'ok': ok,
    'ms': totalMs,
    'steps': steps.map((key, value) => MapEntry(key, value.toJson())),
  };
}

class CliExtensionTester {
  CliExtensionTester({
    required this.mode,
    required this.concurrency,
    required this.timeoutSeconds,
    this.type,
    this.language,
    this.includeUnindexed = false,
  });

  final String mode;
  final int concurrency;
  final int timeoutSeconds;
  final String? type;
  final String? language;
  final bool includeUnindexed;

  Future<Map<String, dynamic>> run(CliExtensionCatalog catalog) async {
    await getIsolateService.start();
    try {
      final results = <CliExtensionTestResult>[];
      var next = 0;
      Future<void> worker() async {
        while (true) {
          final index = next++;
          if (index >= catalog.items.length) return;
          results.add(await _testOne(catalog.items[index]));
        }
      }

      await Future.wait(List.generate(concurrency, (_) => worker()));
      results.sort(
        (a, b) =>
            (a.item.source.name ?? '').compareTo(b.item.source.name ?? ''),
      );
      final passed = results.where((result) => result.ok).length;
      return {
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'version': cliVersion,
        'mode': mode,
        'filters': {
          if (type != null) 'type': type,
          if (language != null) 'language': language,
          'includeUnindexed': includeUnindexed,
        },
        'repository': catalog.root,
        'repositoryRevision': ?catalog.revision,
        'total': results.length,
        'passed': passed,
        'failed': results.length - passed,
        'catalogFailures': catalog.failures,
        'results': results.map((result) => result.toJson()).toList(),
      };
    } finally {
      await getIsolateService.stop();
      ExtensionServiceRegistry.disposeAll();
    }
  }

  Future<CliExtensionTestResult> _testOne(CliExtension item) async {
    final result = CliExtensionTestResult(item);
    final started = Stopwatch()..start();

    Future<void> step(
      String name,
      Future<Object?> Function(ExtensionService service) action,
    ) async {
      final watch = Stopwatch()..start();
      try {
        final value = await withExtensionService(
          item.source,
          (service) =>
              action(service).timeout(Duration(seconds: timeoutSeconds)),
        );
        result.steps[name] = CliExtensionTestStep(
          ok: true,
          ms: watch.elapsedMilliseconds,
          count: _count(value),
          extra: value is Map ? Map<String, dynamic>.from(value) : null,
        );
      } catch (error) {
        result.ok = false;
        result.steps[name] = CliExtensionTestStep(
          ok: false,
          ms: watch.elapsedMilliseconds,
          error: _shortError(error),
          errorType: _errorType(error),
        );
      }
    }

    var supportsLatest = true;
    await step('load', (service) async {
      supportsLatest = service.supportsLatest;
      final preferences = service.getSourcePreferences();
      final headers = service.getHeaders();
      final filters = service.getFilterList().filters;
      return {
        'engine': item.source.sourceCodeLanguage.name,
        'supportsLatest': supportsLatest,
        'preferences': preferences.length,
        'headers': headers.length,
        'filters': filters.length,
      };
    });
    if (mode == 'load' || !result.ok) {
      started.stop();
      result.totalMs = started.elapsedMilliseconds;
      return result;
    }

    MPages? popular;
    List<dynamic> filters = const [];
    await step('popular', (service) async {
      popular = await service.getPopular(1);
      return popular!;
    });
    await step('filters', (service) async {
      filters = service.getFilterList().filters;
      return filters;
    });
    if (supportsLatest) {
      await step('latest', (service) => service.getLatestUpdates(1));
    } else {
      result.steps['latest'] = CliExtensionTestStep(
        ok: true,
        ms: 0,
        extra: {'status': 'unsupported'},
      );
    }
    await step('search', (service) => service.search('a', 1, filters));
    await step('suggestions', (service) => service.getSuggestions('a'));
    if (mode == 'deep') {
      await step('popularPage2', (service) => service.getPopular(2));
    }

    final probe = popular?.list
        .map((item) => item.link)
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (probe == null || probe.isEmpty) {
      result.ok = false;
      result.steps['detail'] = CliExtensionTestStep(
        ok: false,
        ms: 0,
        error: 'popular returned no usable item URL',
      );
    } else {
      MManga? detail;
      await step('detail', (service) async {
        detail = await service.getDetail(probe);
        return detail!;
      });
      await step(
        'recommendations',
        (service) => service.getRecommendations(probe),
      );
      await step('comments', (service) => service.getComments(probe));
      final mediaUrl = detail?.chapters
          ?.map((chapter) => chapter.url)
          .whereType<String>()
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      if (mediaUrl == null || mediaUrl.isEmpty) {
        result.ok = false;
        result.steps['media'] = CliExtensionTestStep(
          ok: false,
          ms: 0,
          error: 'detail returned no usable chapter or episode URL',
        );
      } else if (item.source.itemType == ItemType.manga) {
        List<PageUrl>? pages;
        await step('pages', (service) async {
          pages = await service.getPageList(mediaUrl);
          return pages!;
        });
        if (mode == 'deep' && pages != null && pages!.isNotEmpty) {
          await step('httpProbe', (_) => _probeHttp(pages!.first.url));
        }
      } else if (item.source.itemType == ItemType.novel) {
        String? html;
        await step('html', (service) async {
          html = await service.getHtmlContent(detail?.name ?? '', mediaUrl);
          return html!;
        });
        if (mode == 'deep' && html != null) {
          await step('cleanHtml', (service) => service.cleanHtmlContent(html!));
        }
      } else {
        List<Video>? videos;
        await step('videos', (service) async {
          videos = await service.getVideoList(mediaUrl);
          return videos!;
        });
        if (mode == 'deep' && videos != null && videos!.isNotEmpty) {
          await step('httpProbe', (_) => _probeHttp(videos!.first.url));
        }
      }
    }
    started.stop();
    result.totalMs = started.elapsedMilliseconds;
    return result;
  }
}

/// Serialises the extension engine result types the CLI reports.
dynamic cliSerializeEvalValue(Object? value) {
  if (value is MPages) {
    return {
      'list': value.list.map(cliSerializeEvalValue).toList(),
      'hasNextPage': value.hasNextPage,
    };
  }
  if (value is MManga) {
    return {
      'name': value.name,
      'previewUrl': value.previewUrl,
      'imageUrl': value.imageUrl,
      'link': value.link,
      'author': value.author,
      'artist': value.artist,
      'collectionId': value.collectionId,
      'description': value.description,
      'status': value.status?.name,
      'genre': value.genre,
      'chapters': value.chapters?.map(cliSerializeEvalValue).toList() ?? [],
    };
  }
  if (value is FilterList) return cliSerializeEvalValue(value.toJson());
  if (value is SourcePreference) return cliSerializeEvalValue(value.toJson());
  if (value is MChapter) return value.toJson();
  if (value is Video) return value.toJson();
  if (value is PageUrl) return value.toJson();
  if (value is Iterable) return value.map(cliSerializeEvalValue).toList();
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry('$key', cliSerializeEvalValue(val)),
    );
  }
  return value;
}

/// Writes [report] to [path] (when given) with secrets redacted.
Future<void> writeCliExtensionReport(
  Map<String, dynamic> report,
  String? path,
) async {
  if (path == null) return;
  await File(path).writeAsString(
    const JsonEncoder.withIndent('  ').convert(redactCliOutput(report)),
  );
}

int? _count(Object? value) {
  if (value is MPages) return value.list.length;
  if (value is Iterable) return value.length;
  if (value is MManga) return value.chapters?.length ?? 0;
  return null;
}

String _shortError(Object error) {
  final value = sanitizeCliText(error.toString()).replaceAll('\n', ' ');
  return value.length > 500 ? '${value.substring(0, 497)}...' : value;
}

String _errorType(Object error) {
  if (error is TimeoutException) return 'timeout';
  if (error is SocketException || error is HttpException) return 'network';
  if (error is UnsupportedError) return 'unsupported';
  if (error is FormatException || error is ArgumentError) return 'input';
  return 'runtime';
}

Future<int> _probeHttp(String url) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    request.followRedirects = true;
    final response = await request.close().timeout(const Duration(seconds: 20));
    await response.drain<void>();
    if (response.statusCode >= 400) {
      throw HttpException(
        'HTTP ${response.statusCode} for $url',
        uri: Uri.tryParse(url),
      );
    }
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}
