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
        if (message.startsWith('LoggerLevel.warning:')) {
          Logger.add(
            LoggerLevel.warning,
            message.replaceFirst('LoggerLevel.warning:', ''),
          );
        } else {
          Logger.add(LoggerLevel.info, message);
        }
        if (kDebugMode) {
          print(message.replaceFirst('LoggerLevel.warning:', ''));
        }
      }
    });

    _sendPort = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('Isolate handshake timed out'),
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
    // .getCookie → (isar.settings.getSync(kSettingsId) ?? Settings()).userAgent) is now guarded with
    // a try-catch and falls back to an empty user-agent when isar is not
    // available in this isolate's memory space.

    final receivePort = ReceivePort();
    Zone.current
        .fork(
          specification: ZoneSpecification(
            print: (self, parent, zone, line) {
              isolateData.sendPort.send(line);
            },
          ),
        )
        .run(() async {
          isolateData.sendPort.send(receivePort.sendPort);
          receivePort.listen((message) async {
            if (message is Map<String, dynamic>) {
              final responsePort = message['responsePort'] as SendPort;
              try {
                final url = message['url'] as String?;
                final page = message['page'] as int?;
                final query = message['query'] as String?;
                final filterList = message['filterList'] as List?;
                final source = message['source'] as Source?;
                final proxyServer = message['proxyServer'] as String?;
                final serviceType = message['serviceType'] as String?;
                final useLoggerValue = message['useLogger'] as bool?;
                cfPort = message['cfPort'] as int;
                if (useLoggerValue != null) {
                  useLogger = useLoggerValue;
                }
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
                      default:
                        throw Exception('Unknown service type: $serviceType');
                    }
                  },
                );
                responsePort.send({'success': true, 'data': result});
              } catch (e) {
                responsePort.send({'success': false, 'error': e.toString()});
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
  //     For `getVideoList`, the chapter URL is already a direct media link
  //     (seeded in mock_web_data.dart), so we wrap it as a Video directly.
  //
  //  2. For real extension sources: run withExtensionService directly on
  //     the main thread.  This avoids the "Isolate not running" crash but
  //     real JS extensions will still fail with CORS errors on web (browser
  //     blocks cross-origin XHR from extension JS).  The error message will
  //     be the actual JS/CORS error, which is more useful than the generic
  //     "Isolate not running" message.

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
      throw Exception('Isolate not running');
    }

    final responsePort = ReceivePort();
    final completer = Completer<T>();
    late final StreamSubscription sub;

    // Timeout safeguard
    final timer = Timer(const Duration(seconds: 40), () {
      if (!completer.isCompleted) {
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
          completer.complete(response['data'] as T);
        } else {
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
