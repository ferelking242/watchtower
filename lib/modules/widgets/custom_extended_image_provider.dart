// ignore_for_file: non_nullable_equals_parameter, depend_on_referenced_packages, implementation_imports
import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui show Codec;
import 'package:extended_image_library/src/extended_image_provider.dart';
import 'package:extended_image_library/src/platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http_client_helper/http_client_helper.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/anti_bot/browser_fetch.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:path/path.dart';
import 'package:extended_image_library/src/network/extended_network_image_provider.dart'
    as image_provider;

/// LRU memory cache for image bytes.
@visibleForTesting
class ImageBytesLruCache<K, V> {
  final int _maxSize;
  final _cache = <K, V>{};
  int _currentSize = 0;
  final int Function(V)? _sizeOf;

  ImageBytesLruCache({required int maxSize, int Function(V)? sizeOf})
    : _maxSize = maxSize,
      _sizeOf = sizeOf;

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recently used)
    }
    return value;
  }

  void put(K key, V value) {
    final previous = _cache.remove(key);
    if (previous != null && _sizeOf != null) {
      _currentSize -= _sizeOf(previous);
    }
    _cache[key] = value; // Add to end

    if (_sizeOf != null) {
      _currentSize += _sizeOf(value);
      while (_currentSize > _maxSize && _cache.isNotEmpty) {
        final oldest = _cache.entries.first;
        _currentSize -= _sizeOf(oldest.value);
        _cache.remove(oldest.key);
      }
    } else {
      while (_cache.length > _maxSize) {
        _cache.remove(_cache.keys.first);
      }
    }
  }

  void remove(K key) {
    final value = _cache.remove(key);
    if (value != null && _sizeOf != null) {
      _currentSize -= _sizeOf(value);
    }
  }

  void clear() {
    _cache.clear();
    _currentSize = 0;
  }

  int get length => _cache.length;
  int get currentSize => _currentSize;
}

/// Global memory cache (100 images max, ~50MB)
final _memoryCache = ImageBytesLruCache<String, Uint8List>(
  maxSize: 50 * 1024 * 1024, // 50MB
  sizeOf: (data) => data.length,
);

/// Prevents two widgets requesting the same uncached URL at the same time
/// from starting two network downloads.
final _inFlightImageLoads = <String, Future<Uint8List?>>{};

/// Deduplicates repeated cover-download failures so a broken CDN host does
/// not print one line per card. Keyed by `status|host`; the first few are
/// logged in full, then a periodic running total.
final _coverFailureCounts = <String, int>{};

void _logCoverFailure(String key, String detail) {
  final count = (_coverFailureCounts[key] ?? 0) + 1;
  _coverFailureCounts[key] = count;
  if (count <= 5 || count % 20 == 0) {
    AppLogger.log(
      'échec couverture (#$count) $detail',
      logLevel: LogLevel.warning,
      tag: LogTag.image,
    );
  }
}

/// Whether cached bytes are clearly not an image.
///
/// The persistent cover cache is read back without any validation, so a body
/// that is not an image (a Cloudflare/HTML error page, a truncated response)
/// stays on disk and is re-decoded on every launch — the card shows a
/// placeholder forever, and no extension update can recover it because the
/// bytes are keyed by URL, not re-fetched. Binary image formats always start
/// with a magic byte, never `<`, so an HTML/text body is a safe signal to drop
/// the entry and fetch again.
bool _looksLikeMarkupOrText(Uint8List data) {
  var i = 0;
  while (i < data.length &&
      (data[i] == 0x20 || data[i] == 0x09 || data[i] == 0x0A || data[i] == 0x0D)) {
    i++;
  }
  if (i >= data.length) return true;
  return data[i] == 0x3C; // '<'
}

/// Whether a cover failure is worth retrying through the browser engine.
///
/// Evidence-based, like the rest of the anti-bot path: a bare 403/404 with no
/// Cloudflare marker is a missing or forbidden file the browser would not
/// recover either, so the placeholder is shown at once. `cf-mitigated`,
/// `cf-ray` or `server: cloudflare` on a refusal is the signature this fallback
/// exists for.
bool _looksLikeCloudflareRefusal(StreamedResponse response) {
  final assessment = assessHttpResponse(
    statusCode: response.statusCode,
    headers: response.headers,
  );
  return assessment.cloudflareInvolved;
}

/// Routes image-pipeline events to the release log under the [IMG] tag.
/// The former `debugPrint` calls only exist in debug builds, so a release
/// build gave no way to tell a failed download from an empty `imageUrl`.
void _imgLog(String message, {LogLevel level = LogLevel.debug}) {
  AppLogger.log(message, logLevel: level, tag: LogTag.image);
}

/// Cache metadata for LRU eviction
class _CacheMetadata {
  final String path;
  final int size;
  final DateTime lastAccessed;

  _CacheMetadata({
    required this.path,
    required this.size,
    required this.lastAccessed,
  });
}

/// Global cache manager
class _CacheManager {
  static const _maxCacheSize = 500 * 1024 * 1024; // 500MB

  static Future<int> getCacheSize(io.Directory cacheDir) async {
    if (kIsWeb) return 0;
    if (!await cacheDir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is io.File) {
        totalSize += (await (entity as dynamic).length()) as int;
      }
    }
    return totalSize;
  }

  static Future<void> evictOldestIfNeeded(io.Directory cacheDir) async {
    if (kIsWeb) return;
    final size = await getCacheSize(cacheDir);
    if (size <= _maxCacheSize) return;

    // Collect all cache files with metadata
    final List<_CacheMetadata> files = [];
    await for (final entity in cacheDir.list()) {
      if (entity is io.File) {
        final stat = await entity.stat();
        files.add(
          _CacheMetadata(
            path: entity.path,
            size: stat.size,
            lastAccessed: stat.accessed,
          ),
        );
      }
    }

    // Sort by last accessed (oldest first)
    files.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    // Delete until under limit
    int currentSize = size;
    for (final file in files) {
      if (currentSize <= _maxCacheSize) break;
      try {
        await (io.File(file.path) as dynamic).delete();
        currentSize -= file.size;
      } catch (e) {
        if (kDebugMode) print('Failed to delete cache file: $e');
      }
    }
  }
}

class CustomExtendedNetworkImageProvider
    extends ImageProvider<image_provider.ExtendedNetworkImageProvider>
    with ExtendedImageProvider<image_provider.ExtendedNetworkImageProvider>
    implements image_provider.ExtendedNetworkImageProvider {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments must not be null.
  CustomExtendedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.cache = true,
    this.retries = 3,
    this.timeLimit,
    this.timeRetry = const Duration(milliseconds: 100),
    this.cacheKey,
    this.printError = true,
    this.cacheRawData = false,
    this.cancelToken,
    this.imageCacheName,
    this.imageCacheFolderName,
    this.cacheMaxAge = const Duration(days: 3650),
    this.showCloudFlareError = false,
    this.sourceId,
    this.pageUrl,
  });

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  /// Whether cache raw data if you need to get raw data directly.
  /// For example, we need raw image data to edit,
  /// but [ui.Image.toByteData()] is very slow. So we cache the image
  /// data here.
  @override
  final bool cacheRawData;

  /// The time limit to request image
  @override
  final Duration? timeLimit;

  /// The time to retry to request
  @override
  final int retries;

  /// The time duration to retry to request
  @override
  final Duration timeRetry;

  /// Whether cache image to local
  @override
  final bool cache;

  /// The URL from which the image will be fetched.
  @override
  final String url;

  /// The scale to place in the [ImageInfo] object of the image.
  @override
  final double scale;

  /// The HTTP headers that will be used with [HttpClient.get] to fetch image from network.
  @override
  final Map<String, String>? headers;

  /// The token to cancel network request
  @override
  final CancellationToken? cancelToken;

  /// Custom cache key
  @override
  final String? cacheKey;

  /// print error
  @override
  final bool printError;

  /// The max duration to cache image.
  /// After this time the cache is expired and the image is reloaded.
  @override
  final Duration? cacheMaxAge;

  final bool showCloudFlareError;

  /// Extension the cover belongs to. Passed to the browser fallback so it reuses
  /// that extension's session (cookies, User-Agent) when Cloudflare refuses the
  /// native request.
  final int? sourceId;

  /// HTML page the browser fallback solves the challenge on before fetching the
  /// image. Defaults to the image's origin when null.
  final String? pageUrl;

  final String? imageCacheFolderName;

  @override
  ImageStreamCompleter loadImage(
    image_provider.ExtendedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(
        key as CustomExtendedNetworkImageProvider,
        chunkEvents,
        decode,
      ),
      scale: key.scale,
      chunkEvents: chunkEvents.stream,
      debugLabel: key.url,
      informationCollector: () {
        return <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<image_provider.ExtendedNetworkImageProvider>(
            'Image key',
            key,
          ),
        ];
      },
    );
  }

  @override
  Future<CustomExtendedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<CustomExtendedNetworkImageProvider>(this);
  }

  Future<ui.Codec> _loadAsync(
    CustomExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    final String md5Key = _cacheKeyFor(key);
    ui.Codec? result;
    if (cache) {
      try {
        final Uint8List? data = await _loadCache(key, chunkEvents, md5Key);
        if (data != null) {
          result = await instantiateImageCodec(data, decode);
        }
      } catch (e) {
        _logCoverFailure(
          'decode|${Uri.tryParse(key.url)?.host ?? "?"}',
          '${_shortUrl(key.url)} décodage impossible — $e',
        );
      }
    } else {
      try {
        final Uint8List? data = await _loadNetwork(key, chunkEvents);
        if (data != null) {
          result = await instantiateImageCodec(data, decode);
        }
      } catch (e) {
        _logCoverFailure(
          'decode|${Uri.tryParse(key.url)?.host ?? "?"}',
          '${_shortUrl(key.url)} décodage impossible — $e',
        );
      }
    }

    //Failed to load
    if (result == null) {
      _imgLog(
        'FAILED ${_shortUrl(key.url)} → placeholder',
        level: LogLevel.warning,
      );
      //result = await ui.instantiateImageCodec(kTransparentImage);
      return Future<ui.Codec>.error(StateError('Failed to load $url.'));
    }

    return result;
  }

  String _cacheKeyFor(CustomExtendedNetworkImageProvider key) {
    return cacheKey ?? keyToMd5('${key.url}\n${_headersFingerprint()}');
  }

  @visibleForTesting
  String get cacheKeyForTesting => _cacheKeyFor(this);

  String _headersFingerprint() {
    if (headers == null || headers!.isEmpty) return '';
    final entries = headers!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}=${entry.value}').join('&');
  }

  /// Get the image from cache folder.
  Future<Uint8List?> _loadCache(
    CustomExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent>? chunkEvents,
    String md5Key,
  ) async {
    final pending = _inFlightImageLoads[md5Key];
    if (pending != null) return pending;

    final request = _loadCacheUncoalesced(key, chunkEvents, md5Key);
    _inFlightImageLoads[md5Key] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightImageLoads[md5Key], request)) {
        _inFlightImageLoads.remove(md5Key);
      }
    }
  }

  Future<Uint8List?> _loadCacheUncoalesced(
    CustomExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent>? chunkEvents,
    String md5Key,
  ) async {
    // Check memory cache first
    final cachedData = _memoryCache.get(md5Key);
    if (cachedData != null) {
      _imgLog('MEM-HIT ${_shortUrl(key.url)} (${cachedData.length} B)');
      return cachedData;
    }

    final isPersistentCoverCache =
        !kIsWeb &&
        (imageCacheFolderName == null ||
            imageCacheFolderName == 'cacheimagecover');
    final storage = StorageProvider();
    final io.Directory cacheImagesDirectory = isPersistentCoverCache
        ? await storage.createPersistentCacheDirectory('cacheimagecover')
        : await storage.createCacheDirectory(imageCacheFolderName);
    Uint8List? data;
    final dynamic cacheFile = io.File(join(cacheImagesDirectory.path, md5Key));

    // Older releases stored covers in the OS-purgeable cache directory.
    // Copy legacy entries forward once, but leave the originals untouched.
    if (isPersistentCoverCache &&
        !((cacheFile as dynamic).existsSync() as bool)) {
      try {
        final legacyDirectory = await storage.getCacheDirectory(
          'cacheimagecover',
        );
        final legacyFile = io.File(join(legacyDirectory.path, md5Key));
        if ((legacyFile as dynamic).existsSync() as bool) {
          data = await (legacyFile as dynamic).readAsBytes() as Uint8List;
          try {
            await (cacheFile as dynamic).writeAsBytes(data);
          } catch (error) {
            _imgLog('could not persist migrated cover: $error', level: LogLevel.warning);
          }
        }
      } catch (error) {
        _imgLog('could not migrate legacy cover cache: $error', level: LogLevel.warning);
      }
    }

    // exist, try to find cache image file
    if (!kIsWeb &&
        data == null &&
        (cacheFile as dynamic).existsSync() as bool) {
      if (!isPersistentCoverCache && key.cacheMaxAge != null) {
        final DateTime now = DateTime.now();
        final DateTime lastModified = (cacheFile as dynamic).lastModifiedSync() as DateTime;
        if (now.difference(lastModified) > key.cacheMaxAge!) {
          (cacheFile as dynamic).deleteSync();
          _imgLog('DISK-EXPIRED ${_shortUrl(key.url)}');
        } else {
          final t0 = DateTime.now();
          data = await (cacheFile as dynamic).readAsBytes() as Uint8List;
          final ms = DateTime.now().difference(t0).inMilliseconds;
          _imgLog('DISK-HIT ${_shortUrl(key.url)} (${data.length} B, ${ms}ms)');
        }
      } else {
        final t0 = DateTime.now();
        data = await (cacheFile as dynamic).readAsBytes() as Uint8List;
        final ms = DateTime.now().difference(t0).inMilliseconds;
        _imgLog('DISK-HIT ${_shortUrl(key.url)} (${data.length} B, ${ms}ms)');
      }
    }
    if (data != null && (data.isEmpty || _looksLikeMarkupOrText(data))) {
      if (data.isNotEmpty) {
        _imgLog(
          'cache invalide (contenu non-image) → nouveau téléchargement '
          '${_shortUrl(key.url)}',
          level: LogLevel.warning,
        );
      }
      data = null;
      try {
        (cacheFile as dynamic).deleteSync();
      } catch (_) {}
    }
    if (data != null) _memoryCache.put(md5Key, data);

    // load from network
    if (data == null) {
      _imgLog('CACHE-MISS → network ${_shortUrl(key.url)}');
      data = await _loadNetwork(key, chunkEvents);
      if (data != null) {
        if (!kIsWeb) {
          if (!isPersistentCoverCache) {
            await _CacheManager.evictOldestIfNeeded(cacheImagesDirectory);
          }
          try {
            await (io.File(
              join(cacheImagesDirectory.path, md5Key),
            ) as dynamic).writeAsBytes(data);
          } catch (error) {
            // A full/read-only disk should not make a successfully loaded
            // cover render as a failed image.
            _imgLog('could not write image cache entry: $error', level: LogLevel.warning);
          }
        }

        // Store in memory cache
        _memoryCache.put(md5Key, data);
      }
    }

    return data;
  }

  /// Returns a short display form of a URL for log readability.
  String _shortUrl(String u) {
    try {
      final uri = Uri.parse(u);
      final path = uri.path;
      return '${uri.host}${path.length > 40 ? '…${path.substring(path.length - 37)}' : path}';
    } catch (_) {
      return u.length > 60 ? '${u.substring(0, 57)}…' : u;
    }
  }

  /// One-line summary of the headers a cover request carries.
  ///
  /// The failure mode that matters for covers is a missing `Referer`: a
  /// hotlink-protected CDN answers 403 to every request without it, so a 403
  /// line that does not say whether a `Referer` was sent leaves the reader to
  /// guess between "the app sent none" and "the CDN rejected ours". Both the
  /// start and the failure lines print this summary, so a single grep on
  /// `ref=NONE` localises the bug immediately.
  String _headersSummary() {
    final referer = headers?['Referer'] ?? headers?['referer'];
    final refLabel = referer == null || referer.isEmpty
        ? 'ref=NONE'
        : 'ref=${Uri.tryParse(referer)?.host ?? referer}';
    final userAgent = headers?['User-Agent'] ?? headers?['user-agent'];
    final uaLabel = userAgent == null || userAgent.isEmpty ? 'ua=NONE' : 'ua=yes';
    return '$refLabel $uaLabel';
  }

  /// Fetches a cover the native client was refused through the browser engine.
  ///
  /// Only a real browser holds the Cloudflare clearance for these hosts, so the
  /// request is performed inside the accepted page and the raw bytes come back
  /// base64-encoded. Returns `null` when the browser is unavailable or was
  /// refused too, leaving the caller on the normal failure path.
  Future<Uint8List?> _loadCoverViaBrowser(
    CustomExtendedNetworkImageProvider key,
    Uri resolved,
  ) async {
    if (!BrowserFetchService.isSupported) return null;
    try {
      // The page the fetch runs in decides the Referer the engine sends, so
      // prefer the reader page the extension declared: on a hotlink-protected
      // CDN whose own root serves no HTML, the image's origin is not a page the
      // challenge can be cleared on.
      final referer = headers?['Referer'] ?? headers?['referer'];
      final page = key.pageUrl ??
          ((referer != null && referer.trim().isNotEmpty)
              ? referer.trim()
              : '${resolved.scheme}://${resolved.host}/');
      final response = await BrowserFetchService.fetch(
        resolved.toString(),
        sourceId: key.sourceId,
        headers: headers,
        pageUrl: page,
        binary: true,
        timeout: const Duration(seconds: 15),
      );
      if (response.outcome != BrowserFetchOutcome.resolved) return null;
      final bytes = response.result?.bytes;
      if (bytes == null || bytes.isEmpty || _looksLikeMarkupOrText(bytes)) {
        return null;
      }
      _imgLog(
        'NET-OK    ${_shortUrl(key.url)} (${bytes.length} B, navigateur)',
      );
      return bytes;
    } catch (error) {
      _imgLog(
        'navigateur indisponible pour ${_shortUrl(key.url)} — $error',
        level: LogLevel.debug,
      );
      return null;
    }
  }

  /// Get the image from network.
  Future<Uint8List?> _loadNetwork(
    CustomExtendedNetworkImageProvider key,
    StreamController<ImageChunkEvent>? chunkEvents,
  ) async {
    final t0 = DateTime.now();
    try {
      final Uri resolved = Uri.base.resolve(key.url);
      _imgLog('NET-START ${_shortUrl(key.url)} ${_headersSummary()}');
      final StreamedResponse? response = await _tryGetResponse(resolved);

      if (response == null || response.statusCode != io.HttpStatus.ok) {
        // Only a Cloudflare-style refusal is worth the browser: a 404/410 is a
        // genuinely missing cover, and opening a WebView for it would waste a
        // session and delay the placeholder for nothing.
        if (response != null && _looksLikeCloudflareRefusal(response)) {
          // Cloudflare refuses these covers to the native client whatever the
          // headers (tested: 403 + `cf-mitigated: challenge` with no headers,
          // with UA, Referer and Sec-Fetch alike). The browser engine holds the
          // clearance, so ask it to fetch the bytes from an accepted page.
          final viaBrowser = await _loadCoverViaBrowser(key, resolved);
          if (viaBrowser != null) return viaBrowser;
        }
        final ms = DateTime.now().difference(t0).inMilliseconds;
        final status = response?.statusCode;
        _logCoverFailure(
          '${status ?? "null"}|${resolved.host}',
          '${_shortUrl(key.url)} status=${status ?? "null"} ${ms}ms '
          '${_headersSummary()}',
        );
        return null;
      }

      // Pre-allocate list if content length is known
      final int total = response.contentLength ?? 0;
      final List<int> bytes = total > 0
          ? List<int>.filled(total, 0, growable: true)
          : [];
      int received = 0;

      response.stream.asBroadcastStream();
      await for (var chunk in response.stream) {
        if (total > 0 && received + chunk.length <= total) {
          // Copy directly to pre-allocated list
          bytes.setRange(received, received + chunk.length, chunk);
        } else {
          // Fallback for unknown size
          bytes.addAll(chunk);
        }

        received += chunk.length;
        chunkEvents?.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: received,
            expectedTotalBytes: total,
          ),
        );
      }

      if (bytes.isEmpty) {
        final ms = DateTime.now().difference(t0).inMilliseconds;
        _imgLog(
          'NET-EMPTY ${_shortUrl(key.url)} ${ms}ms',
          level: LogLevel.warning,
        );
        return Future<Uint8List>.error(
          StateError('NetworkImage is an empty file: $resolved'),
        );
      }

      final ms = DateTime.now().difference(t0).inMilliseconds;
      _imgLog('NET-OK    ${_shortUrl(key.url)} (${bytes.length} B, ${ms}ms)');
      return Uint8List.fromList(bytes);
    } on OperationCanceledError catch (_) {
      final ms = DateTime.now().difference(t0).inMilliseconds;
      _imgLog('NET-CANCEL ${_shortUrl(key.url)} ${ms}ms');
      return Future<Uint8List>.error(StateError('User cancel request $url.'));
    } catch (e) {
      final ms = DateTime.now().difference(t0).inMilliseconds;
      _logCoverFailure(
        'err|${Uri.tryParse(key.url)?.host ?? "?"}',
        '${_shortUrl(key.url)} ${ms}ms — $e',
      );
    } finally {
      await chunkEvents?.close();
    }
    return null;
  }

  /// Builds the GET used for one cover download. A fresh instance is needed for
  /// every attempt: an `http.Request` can only be finalized once, so a retry
  /// reusing `response.request` throws instead of re-sending.
  Request _buildImageRequest(Uri resolved) {
    final request = Request('GET', resolved);
    // No `Connection` header: the Rust client speaks HTTP/2, where connection
    // specific headers are forbidden (RFC 9113 §8.2.2) and some WAFs answer
    // 403 when they see one.
    request.headers.addAll({
      ...?headers,
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    });
    return request;
  }

  Future<StreamedResponse> _getResponse(Uri resolved) async {
    var response = await MClient.init(
      showCloudFlareError: showCloudFlareError,
    ).send(_buildImageRequest(resolved));

    if (response.statusCode != 200) {
      // The default (anti-bot aware) client can be answered with a challenge or
      // a transient error for an image; retry once over the plain Dart client
      // before giving up. A `Request` can only be finalized once, so the retry
      // needs a fresh instance rather than `response.request`.
      _imgLog(
        'retry (dart http) ${_shortUrl(resolved.toString())} '
        'after status=${response.statusCode} ${_headersSummary()}',
      );
      final res = await MClient.init(
        reqcopyWith: {'useDartHttpClient': true},
        showCloudFlareError: showCloudFlareError,
      ).send(_buildImageRequest(resolved));
      if (res.statusCode != 200) {
        _logCoverFailure(
          '${res.statusCode}|${resolved.host}',
          '${_shortUrl(resolved.toString())} status=${res.statusCode} '
          '(rhttp=${response.statusCode}, dart=${res.statusCode}) '
          '${_headersSummary()}',
        );
        // The render path only reports `FAILED` with no status, which hides
        // whether this was a server rejection (403/429) or a transport error.
        _imgLog(
          'ÉCHEC définitif ${_shortUrl(resolved.toString())} '
          'rhttp=${response.statusCode} dart=${res.statusCode} '
          '${_headersSummary()}',
          level: LogLevel.warning,
        );
      }
      return res;
    }

    return response;
  }

  // Http get with cancel, exponential backoff retry
  Future<StreamedResponse?> _tryGetResponse(Uri resolved) async {
    cancelToken?.throwIfCancellationRequested();

    int attempt = 0;
    while (attempt < retries) {
      try {
        return await CancellationTokenSource.register(
          cancelToken,
          _getResponse(resolved),
        );
      } catch (e) {
        attempt++;
        if (attempt >= retries) {
          rethrow;
        }

        // Exponential backoff: 100ms, 200ms, 400ms, 800ms, etc.
        final backoffDelay = Duration(
          milliseconds: timeRetry.inMilliseconds * (1 << attempt),
        );

        if (kDebugMode) {
          if (kDebugMode) print(
            'Retry attempt $attempt/$retries after ${backoffDelay.inMilliseconds}ms',
          );
        }

        await Future.delayed(backoffDelay);
        cancelToken?.throwIfCancellationRequested();
      }
    }

    return null;
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CustomExtendedNetworkImageProvider &&
        url == other.url &&
        scale == other.scale &&
        cacheRawData == other.cacheRawData &&
        timeLimit == other.timeLimit &&
        cancelToken == other.cancelToken &&
        timeRetry == other.timeRetry &&
        cache == other.cache &&
        cacheKey == other.cacheKey &&
        _headersFingerprint() == other._headersFingerprint() &&
        retries == other.retries &&
        imageCacheName == other.imageCacheName &&
        imageCacheFolderName == other.imageCacheFolderName &&
        cacheMaxAge == other.cacheMaxAge &&
        showCloudFlareError == other.showCloudFlareError &&
        sourceId == other.sourceId &&
        pageUrl == other.pageUrl &&
        printError == other.printError;
  }

  @override
  int get hashCode => Object.hash(
    url,
    scale,
    cacheRawData,
    timeLimit,
    cancelToken,
    timeRetry,
    cache,
    cacheKey,
    _headersFingerprint(),
    retries,
    imageCacheName,
    imageCacheFolderName,
    cacheMaxAge,
    showCloudFlareError,
    sourceId,
    pageUrl,
    printError,
  );

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';

  @override
  /// Get network image data from cached
  Future<Uint8List?> getNetworkImageData({
    StreamController<ImageChunkEvent>? chunkEvents,
  }) async {
    final String uId = _cacheKeyFor(this);

    if (cache) {
      return await _loadCache(this, chunkEvents, uId);
    }

    return await _loadNetwork(this, chunkEvents);
  }

  @override
  WebHtmlElementStrategy get webHtmlElementStrategy =>
      WebHtmlElementStrategy.fallback;
}
