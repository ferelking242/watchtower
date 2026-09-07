import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/log.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/models/settings.dart';

class _IsolateData {
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  _IsolateData({required this.sendPort, required this.rootIsolateToken});
}

class GetIsolateService {
  bool _isRunning = false;
  Isolate? _getIsolateService;
  ReceivePort? _receivePort;
  StreamSubscription? _receiveSub;
  SendPort? _sendPort;

  Future<void> start() async {
    if (!_isRunning) {
      try {
        await _initGetIsolateService();
      } catch (_) {
        await stop();
      }
    }
  }

  Future<void> _initGetIsolateService() async {
    _receivePort = ReceivePort();

    final rootToken = RootIsolateToken.instance!;

    _getIsolateService = await Isolate.spawn(
      _getIsolateServiceEntryPoint,
      _IsolateData(
        sendPort: _receivePort!.sendPort,
        rootIsolateToken: rootToken,
      ),
    );

    final completer = Completer<SendPort>();
    _receiveSub = _receivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      }
      if (message is String) {
        // ── Route structured extension logs from the isolate to AppLogger ──
        // The JS extension service uses print('[EXT][LEVEL] …') inside the
        // isolate Zone. We parse the prefix here and forward to AppLogger so
        // those entries appear in the in-app log viewer and log file.
        LogLevel lvl = LogLevel.info;
        String body = message;

        if (message.startsWith('[EXT][DEBUG] ')) {
          lvl = LogLevel.debug;
          body = message.substring('[EXT][DEBUG] '.length);
        } else if (message.startsWith('[EXT][INFO] ')) {
          lvl = LogLevel.info;
          body = message.substring('[EXT][INFO] '.length);
        } else if (message.startsWith('[EXT][WARN] ')) {
          lvl = LogLevel.warning;
          body = message.substring('[EXT][WARN] '.length);
        } else if (message.startsWith('[EXT][ERROR] ')) {
          lvl = LogLevel.error;
          body = message.substring('[EXT][ERROR] '.length);
        } else if (message.startsWith('LoggerLevel.warning:')) {
          // Legacy path kept for backward compatibility
          lvl = LogLevel.warning;
          body = message.replaceFirst('LoggerLevel.warning:', '');
        }

        AppLogger.log(body, logLevel: lvl, tag: LogTag.extension_);

        if (kDebugMode) debugPrint(body);
      }
    });

    _sendPort = await completer.future.timeout(
      // 5 s was too short on low-end devices → bumped to 20 s.
      // The isolate does date formatting + QuickJS init which can take
      // several seconds on cold first launch with a slow filesystem.
      const Duration(seconds: 20),
      onTimeout: () => throw StateError('Isolate handshake timed out after 20 s'),
    );
    _isRunning = true;
  }

  static Future<void> _getIsolateServiceEntryPoint(
    _IsolateData isolateData,
  ) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      isolateData.rootIsolateToken,
    );

    await initializeDateFormatting();

    // DO NOT open Isar here.  isar_community does not allow two Dart isolates
    // to call Isar.open() with the same database name — even sequentially the
    // second open returns "IllegalArg: Collection id is invalid".  The main
    // isolate already owns the 'watchtowerDb' handle; opening it again here
    // races with the main isolate's initDB(), causes concurrent deletes, and
    // leaves the main isolate's `isar` global uninitialized → every Riverpod
    // provider crashes with LateInitializationError at startup.
    //
    // The one caller that reads `isar` inside this isolate (MihonService
    // .getCookie → (isar.settings.getSync(kSettingsId) ?? Settings()).userAgent)
    // is guarded with a try-catch and falls back to an empty user-agent when
    // isar is not available in this isolate's memory space.

    final receivePort = ReceivePort();
    Zone.current
        .fork(
          specification: ZoneSpecification(
            print: (self, parent, zone, line) {
              // Forward all print() output (including structured [EXT][LEVEL]
              // lines from JsExtensionService) to the main isolate's listener,
              // which routes them to AppLogger.
              isolateData.sendPort.send(line);
            },
          ),
        )
        .run(() async {
          isolateData.sendPort.send(receivePort.sendPort);
          receivePort.listen((message) async {
            if (message is Map<String, dynamic>) {
              final responsePort = message['responsePort'] as SendPort;
              final serviceType = message['serviceType'] as String?;
              final source = message['source'] as Source?;
              final url = message['url'] as String?;
              final page = message['page'] as int?;
              final query = message['query'] as String?;
              final filterList = message['filterList'] as List?;
              final proxyServer = message['proxyServer'] as String?;
              final useLoggerValue = message['useLogger'] as bool?;
              cfPort = message['cfPort'] as int;
              if (useLoggerValue != null) {
                useLogger = useLoggerValue;
              }

              final srcId = '${source?.name ?? source?.id ?? "?"}[${source?.lang ?? "?"}]';

              // ── Timing + entry log ──
              final sw = Stopwatch()..start();
              print('[EXT][INFO] ▶ $serviceType [$srcId] url=${url ?? page?.toString() ?? query ?? "n/a"}');

              try {
                final result = await withExtensionService(
                  source!,
                  proxyServer ?? '',
                  (service) async {
                    switch (serviceType) {
                      case 'getDetail':
                        return await service.getDetail(url!);
                      case 'getPopular':
                        return await service.getPopular(page!);
                      case 'getLatestUpdates':
                        return await service.getLatestUpdates(page!);
                      case 'search':
                        return await service.search(query!, page!, filterList!);
                      case 'getCustomList':
                        return await service.getCustomList(url!, page!);
                      case 'getVideoList':
                        return await service.getVideoList(url!);
                      case 'getPageList':
                        return await service.getPageList(url!);
                      case 'getHeaders':
                        return Future.value(service.getHeaders());
                      case 'getRecommendations':
                        return await service.getRecommendations(url!);
                      case 'getComments':
                        return await service.getComments(url!);
                      case 'getSuggestions':
                        return await service.getSuggestions(query!);
                      default:
                        throw Exception('Unknown service type: $serviceType');
                    }
                  },
                );
                sw.stop();

                // ── Result summary log ──
                String resultSummary;
                if (result is List) {
                  resultSummary = '${result.length} item(s)';
                } else if (result is MPages) {
                  resultSummary = '${(result as MPages).list?.length ?? 0} items';
                } else {
                  resultSummary = result.runtimeType.toString();
                }
                print('[EXT][INFO] ◀ $serviceType [$srcId] OK ${sw.elapsedMilliseconds}ms → $resultSummary');

                responsePort.send({'success': true, 'data': result});
              } catch (e, st) {
                sw.stop();
                // Classify error origin so the user can immediately tell
                // whether it is an extension bug or an app/network bug.
                final errStr = e.toString();
                final String blame;
                if (errStr.contains('JS CRASH') || errStr.contains('JS error') || errStr.contains('failed to initialise')) {
                  blame = '← BUG IN EXTENSION JS';
                } else if (errStr.contains('SocketException') || errStr.contains('HttpException') || errStr.contains('Connection refused') || errStr.contains('CORS')) {
                  blame = '← NETWORK ERROR (check URL / connectivity)';
                } else if (errStr.contains('JSON') || errStr.contains('FormatException')) {
                  blame = '← EXTENSION returned malformed data';
                } else if (errStr.contains('Timeout') || errStr.contains('timeout')) {
                  blame = '← TIMEOUT (slow server or extension infinite loop)';
                } else {
                  blame = '← APP ERROR (check Dart stack trace)';
                }
                print('[EXT][ERROR] ✗ $serviceType [$srcId] FAILED ${sw.elapsedMilliseconds}ms $blame: $errStr');
                // Log first 8 stack-trace lines
                final stLines = st.toString().split('\n').take(8).join('\n  ');
                print('[EXT][DEBUG] Stack:\n  $stLines');
                responsePort.send({'success': false, 'error': errStr});
              } finally {
                useLogger = false;
              }
            } else if (message == 'dispose') {
              receivePort.close();
            }
          });
        });
  }

  // ── Web fallback ─────────────────────────────────────────────────────────
  //
  // Flutter web does not support Isolate.spawn().  When running on web,
  // the isolate service is never started (see main.dart `if (!kIsWeb)`).
  // Instead of throwing "Isolate not running", we:
  //
  //  1. For local / mock sources (sourceCode is empty): return sensible
  //     empty-but-valid data so the UI renders without crashing.
  //  2. For real extension sources: run withExtensionService directly on
  //     the main thread.  This avoids the "Isolate not running" crash but
  //     real JS extensions will still fail with CORS errors on web.

  static T _webLocalFallback<T>({String? url, String? serviceType}) {
    switch (serviceType) {
      case 'getVideoList':
        final videoUrl = url ?? '';
        return <Video>[Video(videoUrl, 'Direct', videoUrl)] as T;
      case 'getPageList':
        return <PageUrl>[PageUrl(url ?? '')] as T;
      case 'getPopular':
      case 'getLatestUpdates':
      case 'getCustomList':
      case 'search':
        return MPages(list: [], hasNextPage: false) as T;
      case 'getDetail':
        return MManga() as T;
      case 'getHeaders':
        return <String, String>{} as T;
      case 'getRecommendations':
        return <Map<String, dynamic>>[] as T;
      case 'getComments':
        return <Map<String, dynamic>>[] as T;
      case 'getSuggestions':
        return <String>[] as T;
      default:
        throw Exception('Web: unsupported service type "$serviceType" for local/mock source');
    }
  }

  static Future<T> _runOnMainThread<T>({
    String? url,
    int? page,
    String? query,
    List<dynamic>? filterList,
    Source? source,
    String? serviceType,
    String? proxyServer,
  }) async {
    return withExtensionService<T>(
      source!,
      proxyServer ?? '',
      (service) async {
        switch (serviceType) {
          case 'getDetail':
            return await service.getDetail(url!) as T;
          case 'getPopular':
            return await service.getPopular(page!) as T;
          case 'getLatestUpdates':
            return await service.getLatestUpdates(page!) as T;
          case 'search':
            return await service.search(query!, page!, filterList!) as T;
          case 'getCustomList':
            return await service.getCustomList(url!, page!) as T;
          case 'getVideoList':
            return await service.getVideoList(url!) as T;
          case 'getPageList':
            return await service.getPageList(url!) as T;
          case 'getHeaders':
            return service.getHeaders() as T;
          case 'getRecommendations':
            return await service.getRecommendations(url!) as T;
          case 'getComments':
            return await service.getComments(url!) as T;
          case 'getSuggestions':
            return await service.getSuggestions(query!) as T;
          default:
            throw Exception('Unknown service type: $serviceType');
        }
      },
    );
  }

  Future<T> get<T>({
    String? url,
    int? page,
    String? query,
    List<dynamic>? filterList,
    Source? source,
    String? serviceType,
    String? proxyServer,
    bool? autoUpdateExtensions,
    String? androidProxyServer,
    bool? useLogger,
  }) async {
    // ── Web path ──────────────────────────────────────────────────────────
    if (kIsWeb) {
      final isLocalOrMock =
          source?.isLocal == true ||
          (source?.sourceCode?.isEmpty ?? true);

      if (isLocalOrMock) {
        return _webLocalFallback<T>(url: url, serviceType: serviceType);
      }

      return _runOnMainThread<T>(
        url: url,
        page: page,
        query: query,
        filterList: filterList,
        source: source,
        serviceType: serviceType,
        proxyServer: proxyServer,
      );
    }
    // ── Native path ───────────────────────────────────────────────────────

    if (_sendPort == null) {
      AppLogger.log(
        'Isolate not running — cannot execute $serviceType for ${source?.name}',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
      );
      throw Exception('Isolate not running');
    }

    final responsePort = ReceivePort();
    final completer = Completer<T>();
    late final StreamSubscription sub;

    final srcLabel = '${source?.name ?? "?"}[${source?.lang ?? "?"}]';
    AppLogger.log(
      '→ $serviceType [$srcLabel] url=${url ?? page?.toString() ?? query ?? "n/a"}',
      logLevel: LogLevel.debug,
      tag: LogTag.extension_,
    );
    final sw = Stopwatch()..start();

    // Timeout safeguard — log the timeout clearly
    final timer = Timer(const Duration(seconds: 40), () {
      if (!completer.isCompleted) {
        sw.stop();
        AppLogger.log(
          '✗ $serviceType [$srcLabel] TIMEOUT after ${sw.elapsedMilliseconds}ms '
          '← extension or server took too long',
          logLevel: LogLevel.error,
          tag: LogTag.extension_,
        );
        sub.cancel();
        responsePort.close();
        completer.completeError('Isolate response timeout');
      }
    });

    sub = responsePort.listen((response) {
      timer.cancel();
      sub.cancel();
      responsePort.close();
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          sw.stop();
          // Success is already logged by the isolate entry point;
          // we just log the round-trip time here at DEBUG level.
          AppLogger.log(
            '← $serviceType [$srcLabel] OK ${sw.elapsedMilliseconds}ms (round-trip)',
            logLevel: LogLevel.debug,
            tag: LogTag.extension_,
          );
          completer.complete(response['data'] as T);
        } else {
          sw.stop();
          // Error detail already logged in the isolate; echo at ERROR level here
          // so it's visible even in Normal log mode.
          AppLogger.log(
            '✗ $serviceType [$srcLabel] ERROR after ${sw.elapsedMilliseconds}ms: ${response['error']}',
            logLevel: LogLevel.error,
            tag: LogTag.extension_,
          );
          completer.completeError(response['error']);
        }
      } else {
        completer.completeError('Invalid isolate response: $response');
      }
    });

    _sendPort!.send({
      'url': ?url,
      'page': ?page,
      'query': ?query,
      'filterList': ?filterList,
      'serviceType': ?serviceType,
      'source': ?source,
      'proxyServer': ?proxyServer,
      'responsePort': responsePort.sendPort,
      'useLogger': ?useLogger,
      'cfPort': cfPort,
    });

    return completer.future;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _sendPort?.send('dispose');
    _getIsolateService?.kill(priority: Isolate.immediate);
    await _receiveSub?.cancel();
    _receivePort?.close();
    _receiveSub = null;
    _sendPort = null;
    _getIsolateService = null;
    _receivePort = null;
    _isRunning = false;
  }
}

final getIsolateService = GetIsolateService();
