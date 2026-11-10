import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as path;
part 'convert_to_cbz.g.dart';

/// Metadata for ComicInfo.xml generation (serializable for isolate).
class ComicInfoData {
  final String? title;
  final String? series;
  final String? number;
  final String? writer;
  final String? penciller;
  final String? summary;
  final String? genre;
  final String? translator;
  final String? publishingStatusStr;
  final int pageCount;

  const ComicInfoData({
    this.title,
    this.series,
    this.number,
    this.writer,
    this.penciller,
    this.summary,
    this.genre,
    this.translator,
    this.publishingStatusStr,
    this.pageCount = 0,
  });
}

@riverpod
Future<List<String>> convertToCBZ(
  Ref ref,
  String chapterDir,
  String mangaDir,
  String chapterName,
  List<String> pageList, {
  ComicInfoData? comicInfo,
}) async {
  return convertToMangaArchive(
    chapterDir: chapterDir,
    mangaDir: mangaDir,
    chapterName: chapterName,
    pageList: pageList,
    formatExtension: '.cbz',
    comicInfo: comicInfo,
  );
}

Future<List<String>> convertToMangaArchive({
  required String chapterDir,
  required String mangaDir,
  required String chapterName,
  required List<String> pageList,
  required String formatExtension,
  ComicInfoData? comicInfo,
  int compressionLevel = 0,
  void Function(int done, int total, String currentName)? onProgress,
}) async {
  if (formatExtension != '.cbz' &&
      formatExtension != '.zip' &&
      formatExtension != '.cbr' &&
      formatExtension != '.cb7') {
    throw ArgumentError.value(
      formatExtension,
      'formatExtension',
      'Only real ZIP-based manga archives are supported.',
    );
  }
  final level = compressionLevel.clamp(0, 9);
  if (onProgress == null) {
    // No streaming requested — a one-shot helper avoids isolate ping-pong.
    return Isolate.run(
      () => _convertToMangaArchive((
        chapterDir,
        mangaDir,
        chapterName,
        pageList,
        comicInfo,
        formatExtension,
        level,
      )),
    );
  }

  final receivePort = ReceivePort();
  final completer = Completer<List<String>>();
  late final StreamSubscription<dynamic> sub;
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn(
      _archiveIsolateEntry,
      <String, dynamic>{
        'sendPort': receivePort.sendPort,
        'chapterDir': chapterDir,
        'mangaDir': mangaDir,
        'chapterName': chapterName,
        'pageList': pageList,
        'comicInfo': comicInfo,
        'formatExtension': formatExtension,
        'compressionLevel': level,
      },
      onError: receivePort.sendPort,
      onExit: receivePort.sendPort,
      errorsAreFatal: true,
    );
    sub = receivePort.listen((message) {
      if (message is Map) {
        if (message.containsKey('progress')) {
          onProgress(
            message['done'] as int,
            message['total'] as int,
            message['name'] as String? ?? '',
          );
        } else if (message.containsKey('result')) {
          if (!completer.isCompleted) {
            completer.complete(
              (message['result'] as List).cast<String>(),
            );
          }
        } else if (message.containsKey('error')) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError(message['error'] as String? ?? 'archive failed'),
            );
          }
        }
      } else if (message is List && message.isNotEmpty && message[0] == null) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('archive isolate crashed: ${message.length > 1 ? message[1] : ''}'),
          );
        }
      }
    });
    return await completer.future;
  } finally {
    try {
      await sub.cancel();
    } catch (_) {}
    receivePort.close();
    isolate?.kill(priority: Isolate.immediate);
  }
}

@pragma('vm:entry-point')
Future<void> _archiveIsolateEntry(Map<String, dynamic> args) async {
  final sendPort = args['sendPort'] as SendPort;
  try {
    final result = await _convertToMangaArchive(
      (
        args['chapterDir'] as String,
        args['mangaDir'] as String,
        args['chapterName'] as String,
        (args['pageList'] as List).cast<String>(),
        args['comicInfo'] as ComicInfoData?,
        args['formatExtension'] as String,
        args['compressionLevel'] as int,
      ),
      onProgress: (done, total, name) {
        sendPort.send(<String, dynamic>{
          'progress': true,
          'done': done,
          'total': total,
          'name': name,
        });
      },
    );
    sendPort.send(<String, dynamic>{'result': result});
  } catch (e) {
    sendPort.send(<String, dynamic>{'error': e.toString()});
  }
}

String _buildComicInfoXml(ComicInfoData info, int pageCount) {
  final sb = StringBuffer();
  sb.writeln('<?xml version="1.0" encoding="utf-8"?>');
  sb.writeln(
    '<ComicInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
  );

  void addTag(String tag, String? value) {
    if (value != null && value.isNotEmpty) {
      final escaped = _xmlEscape(value);
      sb.writeln('  <$tag>$escaped</$tag>');
    }
  }

  addTag('Title', info.title);
  addTag('Series', info.series);
  addTag('Number', info.number);
  addTag('Writer', info.writer);
  addTag('Penciller', info.penciller);
  addTag('Summary', info.summary);
  addTag('Genre', info.genre);
  addTag('Translator', info.translator);
  if (pageCount > 0) {
    sb.writeln('  <PageCount>$pageCount</PageCount>');
  }
  addTag('PublishingStatusTachiyomi', info.publishingStatusStr);

  sb.writeln('</ComicInfo>');
  return sb.toString();
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

Future<List<String>> _convertToMangaArchive(
  (String, String, String, List<String>, ComicInfoData?, String, int) datas, {
  void Function(int done, int total, String currentName)? onProgress,
}) async {
  final (
    chapterDir,
    mangaDir,
    chapterName,
    pageList,
    comicInfo,
    formatExtension,
    compressionLevel,
  ) = datas;
  final imagesPaths = pageList.where((path) => path.endsWith('.jpg')).toList()
    ..sort();

  if (imagesPaths.isEmpty) return imagesPaths;

  // ── Compression profile ─────────────────────────────────────────────────
  // Deflating JPEGs barely shrinks them, so from level 1 up we also re-encode
  // each page as an optimised JPEG (lower quality + 4:2:0 chroma) — that is
  // what actually shrinks a comic archive. Higher levels additionally cap the
  // pixel dimensions (a big lever on scans much larger than a phone screen);
  // the caps stay well above readable resolution so text never blurs. Level 0
  // keeps the original bytes and only does a fast deflate.
  final jpegQuality = compressionLevel <= 0
      ? null
      : (92 - (compressionLevel - 1) * 6).clamp(40, 92);
  final maxDimension = switch (compressionLevel) {
    <= 0 => null,
    <= 4 => null,
    <= 6 => 2000,
    <= 8 => 1800,
    _ => 1600,
  };
  final deflateLevel = compressionLevel <= 0
      ? 1
      : (1 + ((8 * compressionLevel) / 9).round()).clamp(1, 9);

  final archive = Archive();
  final archivePath = path.join(mangaDir, "$chapterName$formatExtension");
  final List<String> missingFiles = [];
  final List<String> includedFiles = [];

  final total = imagesPaths.length;
  // Level 0 keeps the original bytes, so there is no per-page work to spread;
  // reading each file inline is then the fastest path. From level 1 up every
  // page is decoded and re-encoded as JPEG, which is pure CPU work, so it runs
  // across the device's cores instead of one. The loop stays sequential for
  // level 0 to keep memory bounded and the archive order deterministic.
  if (jpegQuality == null) {
    for (var i = 0; i < total; i++) {
      final imagePath = imagesPaths[i];
      final file = File(imagePath);
      if (!file.existsSync()) {
        missingFiles.add(imagePath);
        continue;
      }
      final fileName = path.basename(imagePath);
      archive.add(ArchiveFile.bytes(fileName, file.readAsBytesSync()));
      includedFiles.add(imagePath);
      onProgress?.call(i + 1, total, fileName);
    }
  } else {
    await _packRecompressed(
      archive: archive,
      imagesPaths: imagesPaths,
      quality: jpegQuality,
      maxDimension: maxDimension,
      missingFiles: missingFiles,
      includedFiles: includedFiles,
      onProgress: onProgress,
    );
  }

  // Add ComicInfo.xml if metadata is provided
  if (comicInfo != null) {
    final xml = _buildComicInfoXml(comicInfo, includedFiles.length);
    archive.add(ArchiveFile.bytes('ComicInfo.xml', utf8.encode(xml)));
  }

  if (missingFiles.isNotEmpty) {
    final missingListStr = missingFiles.join(", ");
    throw Exception(
      "Archive was not created because pages are missing: $missingListStr",
    );
  }

  final temporaryPath = '$archivePath.part';
  try {
    final encoded = ZipEncoder().encodeBytes(archive, level: deflateLevel);
    final temporaryFile = File(temporaryPath);
    temporaryFile.writeAsBytesSync(encoded, flush: true);
    // flush:true only pushes to the OS page cache. An fsync is required so the
    // bytes survive an abrupt power loss / process kill; otherwise the archive
    // can be lost after the *download* already reported success and the source
    // pages were deleted — the "reprise après redémarrage" data-loss bug.
    _fsyncFile(temporaryFile);
    final target = File(archivePath);
    if (target.existsSync()) target.deleteSync();
    temporaryFile.renameSync(archivePath);
  } catch (e) {
    final partial = File(temporaryPath);
    if (partial.existsSync()) partial.deleteSync();
    throw FileSystemException(
      "Failed to create/write ZIP-based manga archive: $e",
      archivePath,
    );
  }
  final sourceDirectory = Directory(chapterDir);
  if (sourceDirectory.existsSync()) {
    try {
      sourceDirectory.deleteSync(recursive: true);
    } catch (e) {
      // The archive has already been flushed and renamed successfully. A
      // leftover source folder is recoverable and must not turn a valid CBZ
      // into a failed download.
      debugPrint(
        'Watchtower: archive created, but chapter cleanup failed '
        'for $chapterDir: $e',
      );
    }
  }

  return includedFiles;
}

/// Best-effort fsync of a just-written file so its bytes are durable on the
/// file system after a crash. Silently ignored when the platform refuses it.
void _fsyncFile(File file) {
  // `File.openSync` resolves to a dart:io web stub on Web builds. Keep this
  // best-effort durability hook dynamic so the native RandomAccessFile can
  // still use flushSync/closeSync while the Web path safely catches the
  // unsupported operations.
  dynamic handle;
  try {
    handle = file.openSync(mode: FileMode.append);
    handle.flushSync();
  } catch (_) {
  } finally {
    try {
      handle?.closeSync();
    } catch (_) {}
  }
}

/// Re-encode a JPEG page at [quality] with 4:2:0 chroma subsampling, which is
/// what actually shrinks a comic archive. When [maxDimension] is set the page
/// is downscaled so neither side exceeds it (aspect ratio preserved) using a
/// smooth interpolation so text stays crisp. Returns null when the bytes are
/// not a decodable image, so the caller keeps the original page untouched.
Uint8List? _recompressJpeg(Uint8List bytes, int quality, int? maxDimension) {
  try {
    var decoded = img.decodeJpg(bytes);
    if (decoded == null) return null;
    if (maxDimension != null &&
        (decoded.width > maxDimension || decoded.height > maxDimension)) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(
              decoded,
              width: maxDimension,
              interpolation: img.Interpolation.cubic,
            )
          : img.copyResize(
              decoded,
              height: maxDimension,
              interpolation: img.Interpolation.cubic,
            );
    }
    return img.encodeJpg(
      decoded,
      quality: quality,
      chroma: img.JpegChroma.yuv420,
    );
  } catch (_) {
    return null;
  }
}

/// Decodes and re-encodes every page across the device's cores, then adds them
/// to [archive] in playlist order.
///
/// The re-encode is pure CPU work and used to run one page at a time, which
/// left every core but one idle for the whole chapter. Each page is independent
/// (only its bytes and its index matter), so the pages are split into as many
/// chunks as the device has cores and each chunk is recompressed in its own
/// isolate. Results are placed by index, so the archive order is identical to
/// the sequential version, and the chunk count is capped so a large chapter
/// cannot hold dozens of decoded bitmaps in memory at once.
Future<void> _packRecompressed({
  required Archive archive,
  required List<String> imagesPaths,
  required int quality,
  required int? maxDimension,
  required List<String> missingFiles,
  required List<String> includedFiles,
  required void Function(int done, int total, String currentName)? onProgress,
}) async {
  final total = imagesPaths.length;
  final packed = List<Uint8List?>.filled(total, null);
  final missing = List<bool>.filled(total, false);
  final workerCount = (Platform.numberOfProcessors - 1).clamp(1, 6);
  var done = 0;

  await Future.wait(
    List.generate(workerCount, (worker) async {
      final indices = [
        for (var i = worker; i < total; i += workerCount) i,
      ];
      if (indices.isEmpty) return;
      final paths = [for (final i in indices) imagesPaths[i]];
      final batch = await Isolate.run(
        () => _recompressBatch(paths, quality, maxDimension),
      );
      for (var k = 0; k < indices.length; k++) {
        final index = indices[k];
        final (isMissing, bytes) = batch[k];
        if (isMissing) {
          missing[index] = true;
        } else {
          packed[index] = bytes;
        }
        done++;
        onProgress?.call(done, total, path.basename(imagesPaths[index]));
      }
    }),
  );

  // Placed by index, not by completion order: the workers finish out of order,
  // so the archive and the returned page list must be rebuilt in page order.
  for (var i = 0; i < total; i++) {
    if (missing[i]) {
      missingFiles.add(imagesPaths[i]);
      continue;
    }
    final bytes = packed[i];
    if (bytes != null) {
      includedFiles.add(imagesPaths[i]);
      archive.add(ArchiveFile.bytes(path.basename(imagesPaths[i]), bytes));
    }
  }
}

/// Recompresses one chunk of pages in a worker isolate.
///
/// Returns one `(isMissing, bytes)` record per input path, in the same order.
/// A missing file is flagged rather than skipped so the caller keeps the
/// "archive refused because pages are missing" contract.
List<(bool, Uint8List)> _recompressBatch(
  List<String> paths,
  int quality,
  int? maxDimension,
) {
  final out = <(bool, Uint8List)>[];
  for (final imagePath in paths) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      out.add((true, Uint8List(0)));
      continue;
    }
    final bytes = file.readAsBytesSync();
    out.add((false, _recompressJpeg(bytes, quality, maxDimension) ?? bytes));
  }
  return out;
}
