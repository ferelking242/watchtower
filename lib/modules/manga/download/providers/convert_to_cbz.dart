import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:watchtower/services/download_manager/image_payload_validator.dart';
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
  return compute(_convertToCBZ, (
    chapterDir,
    mangaDir,
    chapterName,
    pageList,
    comicInfo,
  ));
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

List<String> _convertToCBZ(
  (String, String, String, List<String>, ComicInfoData?) datas,
) {
  final (chapterDir, mangaDir, chapterName, pageList, comicInfo) = datas;
  final imagesPaths = pageList.where((path) => path.endsWith('.jpg')).toList()
    ..sort((a, b) {
      final aIndex = int.tryParse(path.basenameWithoutExtension(a));
      final bIndex = int.tryParse(path.basenameWithoutExtension(b));
      if (aIndex != null && bIndex != null) return aIndex.compareTo(bIndex);
      return a.compareTo(b);
    });

  if (imagesPaths.isEmpty) {
    throw StateError('Aucune page manga à ajouter au CBZ.');
  }

  final archive = Archive();
  final cbzPath = path.join(mangaDir, "$chapterName.cbz");
  final List<String> includedFiles = [];

  for (var imagePath in imagesPaths) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw FileSystemException('Page manga manquante', imagePath);
    }
    final bytes = file.readAsBytesSync();
    final prefix = bytes.sublist(0, bytes.length < 512 ? bytes.length : 512);
    final tail = bytes.sublist(bytes.length > 32 ? bytes.length - 32 : 0);
    if (!isReusableImagePayload(
      length: bytes.length,
      prefix: prefix,
      tail: tail,
    )) {
      throw FileSystemException(
        'La page manga est vide ou invalide',
        imagePath,
      );
    }
    final fileName = path.basename(imagePath);
    archive.add(ArchiveFile.bytes(fileName, bytes));
    includedFiles.add(imagePath);
  }

  // Add ComicInfo.xml if metadata is provided
  if (comicInfo != null) {
    final xml = _buildComicInfoXml(comicInfo, includedFiles.length);
    archive.add(ArchiveFile.bytes('ComicInfo.xml', utf8.encode(xml)));
  }

  final temporaryFile = File('$cbzPath.part');
  final backupFile = File('$cbzPath.previous');
  try {
    final cbzData = ZipEncoder().encode(archive);
    if (temporaryFile.existsSync()) temporaryFile.deleteSync();
    temporaryFile.writeAsBytesSync(cbzData, flush: true);

    var hadPreviousArchive = false;
    if (File(cbzPath).existsSync()) {
      if (backupFile.existsSync()) backupFile.deleteSync();
      File(cbzPath).renameSync(backupFile.path);
      hadPreviousArchive = true;
    }
    try {
      temporaryFile.renameSync(cbzPath);
    } catch (_) {
      if (hadPreviousArchive && backupFile.existsSync()) {
        backupFile.renameSync(cbzPath);
      }
      rethrow;
    }
    if (backupFile.existsSync()) backupFile.deleteSync();
  } catch (e) {
    throw FileSystemException("Failed to create/write CBZ file: $e", cbzPath);
  }

  try {
    Directory(chapterDir).deleteSync(recursive: true);
  } catch (e) {
    debugPrint('CBZ created; source image cleanup failed: $e');
  }

  return includedFiles;
}
