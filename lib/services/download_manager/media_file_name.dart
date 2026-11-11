import 'package:watchtower/utils/extensions/string_extensions.dart';

/// Deterministic on-disk base name (no extension) for a chapter.
///
/// A null or blank title used to reach `chapter.name!` and abort the download
/// with "Null check operator used on a null value". Falling back to the chapter
/// id keeps the writer and every reader (share, delete, size scan) on the very
/// same name, so nothing is ever written where it cannot be found again.
String safeChapterBaseName({required String? chapterName, int? chapterId}) {
  if (chapterName != null && chapterName.isNotEmpty) {
    return chapterName
        .replaceForbiddenCharacters(' ')
        .truncateToBytes(kMaxDownloadNameBytes);
  }
  return 'chapter_${chapterId ?? 'unknown'}';
}

/// Builds the on-disk base name (no extension) of an episode's MP4.
///
/// A video is downloaded to `<name> [360p].mp4`, the quality tag coming from
/// the record's `quality` field. Share, open and delete used to rebuild the
/// name from the chapter title alone, so they looked for `<name>.mp4`, missed
/// the file the downloader had actually written and left it orphaned on disk.
/// Both the writer and the readers must go through this one function.
///
/// The base is truncated *before* the tag is appended so the ` [360p]` suffix
/// always survives whole and the result stays within [kMaxDownloadNameBytes]
/// UTF-8 bytes (see the constant for why that budget exists).
String animeMp4BaseName({
  required String? chapterName,
  int? chapterId,
  String? quality,
}) {
  final resolution = _qualityDigits(quality);
  final suffix = RegExp(r'^\d{3,4}$').hasMatch(resolution)
      ? ' [${resolution}p]'
      : '';
  final base = safeChapterBaseName(chapterName: chapterName, chapterId: chapterId)
      .truncateToBytes(kMaxDownloadNameBytes - suffix.length);
  return '$base$suffix';
}

/// Extracts the leading 3–4 digit resolution ("1080", "360") from a quality
/// label such as `1080p` or `1280x720`; returns an empty string when none.
String _qualityDigits(String? raw) {
  if (raw == null) return '';
  final match = RegExp(r'(\d{3,4})').firstMatch(raw);
  return match?.group(1) ?? '';
}
