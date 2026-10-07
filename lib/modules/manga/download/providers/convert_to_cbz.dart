import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
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
}) {
  if (formatExtension != '.cbz' && formatExtension != '.zip') {
    throw ArgumentError.value(
      formatExtension,
      'formatExtension',
      'Only real ZIP-based manga archives are supported.',
    );
  }
  return compute(_convertToMangaArchive, (
    chapterDir,
    mangaDir,
    chapterName,
    pageList,
    comicInfo,
    formatExtension,
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

List<String> _convertToMangaArchive(
  (String, String, String, List<String>, ComicInfoData?, String) datas,
) {
  final (
    chapterDir,
    mangaDir,
    chapterName,
    pageList,
    comicInfo,
    formatExtension,
  ) = datas;
  final imagesPaths = pageList.where((path) => path.endsWith('.jpg')).toList()
    ..sort();

  if (imagesPaths.isEmpty) return imagesPaths;

  final archive = Archive();
  final archivePath = path.join(mangaDir, "$chapterName$formatExtension");
  final List<String> missingFiles = [];
  final List<String> includedFiles = [];

  for (var imagePath in imagesPaths) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      missingFiles.add(imagePath);
      continue;
    }
    final bytes = file.readAsBytesSync();
    final fileName = path.basename(imagePath);
    archive.add(ArchiveFile.bytes(fileName, bytes));
    includedFiles.add(imagePath);
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
    final encoded = ZipEncoder().encode(archive);
    File(temporaryPath).writeAsBytesSync(encoded, flush: true);
    final target = File(archivePath);
    if (target.existsSync()) target.deleteSync();
    File(temporaryPath).renameSync(archivePath);
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
