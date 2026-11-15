import 'dart:async';
import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:watchtower/modules/manga/reader/u_chap_data_preload.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/utils/chapter_link.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';
import 'package:path/path.dart' as p;

extension FileFormatter on num {
  String formattedFileSize({bool base1024 = true}) {
    if (this <= 0) return "0.00 B";
    final base = base1024 ? 1024 : 1000;
    final units = base1024
        ? ["B", "KiB", "MiB", "GiB", "TiB"]
        : ["B", "kB", "MB", "GB", "TB"];
    int digitGroups = (log(this) / log(base)).floor().clamp(
      0,
      units.length - 1,
    );
    return "${NumberFormat("#,##0.#").format(this / pow(base, digitGroups))} ${units[digitGroups]}";
  }
}

extension LetExtension<T> on T {
  R let<R>(R Function(T) block) {
    return block(this);
  }
}

/// A [MemoryImage] whose decode is bounded to roughly the on-screen size.
///
/// Custom covers are stored on the `Manga` row as the *original* image blob.
/// A bare `MemoryImage` decodes it at full resolution, so a grid of covers can
/// allocate hundreds of megabytes of bitmaps and push the app into the
/// low-memory killer (the Samsung ANR with kswapd at ~88 %). Bounding the
/// decode keeps the same pixels on screen at a fraction of the memory.
ImageProvider coverMemoryImage(Uint8List bytes, {int width = 400}) =>
    ResizeImage(MemoryImage(bytes), width: width, allowUpscaling: false);

extension MedianExtension on List<int> {
  int median() {
    final sorted = List<int>.from(this)..sort();
    var middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 1) {
      return sorted[middle];
    } else {
      return ((sorted[middle - 1] + sorted[middle]) / 2).round();
    }
  }

  int arithmeticMean() {
    return isNotEmpty ? (reduce((e1, e2) => e1 + e2) / length).round() : 0;
  }
}

extension ImageProviderExtension on ImageProvider {
  Future<Uint8List?> getBytes(
    BuildContext context, {
    ImageByteFormat format = ImageByteFormat.png,
  }) async {
    final imageStream = resolve(createLocalImageConfiguration(context));
    final Completer<Uint8List?> completer = Completer<Uint8List?>();
    final ImageStreamListener listener = ImageStreamListener((
      imageInfo,
      synchronousCall,
    ) async {
      final bytes = await imageInfo.image.toByteData(format: format);
      if (!completer.isCompleted) {
        completer.complete(bytes?.buffer.asUint8List());
      }
    });
    imageStream.addListener(listener);
    final imageBytes = await completer.future;
    imageStream.removeListener(listener);
    return imageBytes;
  }
}

extension UChapDataPreloadExtensions on UChapDataPreload {
  /// Raw bytes of the page.
  ///
  /// Local archives and downloaded chapters are read straight from disk. A
  /// remote page goes through the *same* [CustomExtendedNetworkImageProvider]
  /// the reader renders from, so the bytes come out of the identical disk
  /// cache entry (key = `md5(url + headers fingerprint)`). The previous
  /// implementation re-derived the key as `md5(url)` only and never matched
  /// what the reader had written, which is why "Rogner les bordures" silently
  /// did nothing: the crop step received `null` for every page.
  Future<Uint8List?> get getImageBytes => getImageBytesWith();

  Future<Uint8List?> getImageBytesWith({
    Map<String, String>? headers,
    int? sourceId,
  }) async {
    if (archiveImage != null) return archiveImage;
    if (isLocale == true && directory != null && index != null) {
      return io.File(
        p.join(directory!.path, "${padIndex(index!)}.jpg"),
      ).readAsBytes();
    }
    if (pageUrl == null || pageUrl!.url.trim().isEmpty) return null;
    return buildNetworkImageProvider(
      headers: headers,
      sourceId: sourceId,
    ).getNetworkImageData();
  }

  /// The network provider the reader uses for this page. Kept in one place so
  /// the crop pipeline and the on-screen widget can never disagree on the
  /// cache key or on the headers a request carries.
  CustomExtendedNetworkImageProvider buildNetworkImageProvider({
    Map<String, String>? headers,
    bool showCloudFlareError = true,
    int? sourceId,
  }) {
    return CustomExtendedNetworkImageProvider(
      pageUrl!.url.trim(),
      cache: true,
      cacheMaxAge: const Duration(days: 7),
      showCloudFlareError: showCloudFlareError,
      imageCacheFolderName: "cacheimagemanga",
      headers: {...?pageUrl!.headers, ...?headers},
      // The owning extension, so the request replays the same browser session
      // (cookies + User-Agent) that cleared Cloudflare. Without it the native
      // client sends no `cf_clearance` and the CDN answers 403.
      sourceId: sourceId,
    );
  }

  ImageProvider<Object> getImageProvider(
    WidgetRef ref,
    bool showCloudFlareError,
  ) {
    final data = this;

    if (data.isTransitionPage) {
      return const AssetImage('assets/transparent.png')
          as ImageProvider<Object>;
    }

    final isLocale = data.isLocale!;
    final archiveImage = data.archiveImage;
    final cropBorders = ref.watch(cropBordersStateProvider);
    final chapterManga = data.chapter == null
        ? null
        : resolveChapterManga(data.chapter!);
    if (cropBorders && data.cropImage != null) {
      return ExtendedMemoryImageProvider(data.cropImage!);
    }
    if (isLocale) {
      if (archiveImage != null) return ExtendedMemoryImageProvider(archiveImage);
      return ExtendedFileImageProvider(
        _localIoFile(
          p.join(data.directory!.path, "${padIndex(data.index!)}.jpg"),
        ),
      );
    }
    // Remote page: the headers provider needs the owning title's source. When
    // the link is missing we fall back to the plain provider (no custom
    // headers) rather than crashing on the `!` dereference.
    return chapterManga == null
        ? buildNetworkImageProvider(showCloudFlareError: showCloudFlareError)
        : buildNetworkImageProvider(
            showCloudFlareError: showCloudFlareError,
            sourceId: chapterManga.sourceId,
            headers: ref.watch(
              headersProvider(
                source: chapterManga.source!,
                lang: chapterManga.lang!,
                sourceId: chapterManga.sourceId,
              ),
            ),
          );
  }
}

dynamic _localIoFile(String path) => io.File(path);
