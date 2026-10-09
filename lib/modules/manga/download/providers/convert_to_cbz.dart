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
    return compute(_convertToMangaArchive, (
      chapterDir,
      mangaDir,
      chapterName,
      pageList,
      comicInfo,
      formatExtension,
      level,
    ));
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
void _archiveIsolateEntry(Map<String, dynamic> args) {
  final sendPort = args['sendPort'] as SendPort;
  try {
    final result = _convertToMangaArchive(
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

List<String> _convertToMangaArchive(
  (String, String, String, List<String>, ComicInfoData?, String, int) datas, {
  void Function(int done, int total, String currentName)? onProgress,
}) {
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
  for (var i = 0; i < total; i++) {
    final imagePath = imagesPaths[i];
    final file = File(imagePath);
    if (!file.existsSync()) {
      missingFiles.add(imagePath);
      continue;
    }
    final bytes = file.readAsBytesSync();
    final fileName = path.basename(imagePath);
    final packed = jpegQuality == null
        ? bytes
        : (_recompressJpeg(bytes, jpegQuality, maxDimension) ?? bytes);
    archive.add(ArchiveFile.bytes(fileName, packed));
    includedFiles.add(imagePath);
    onProgress?.call(i + 1, total, fileName);
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
  try {
    Directory(chapterDir).deleteSync(recursive: true);
  } catch (e) {
    throw FileSystemException("Failed to delete chapter directory", chapterDir);
  }

  return includedFiles;
}

/// Best-effort fsync of a just-written file so its bytes are durable on the
/// file system after a crash. Silently ignored when the platform refuses it.
void _fsyncFile(File file) {
  RandomAccessFile? handle;
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
