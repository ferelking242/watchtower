import 'dart:convert';

/// Byte budget for a download file's name, excluding its extension.
///
/// Linux, Android and iOS cap one path component at 255 bytes (`NAME_MAX`).
/// The HLS assembler appends `.mp4.part.joined` (16 bytes) to the final name
/// while it merges, so the name must leave that much headroom: 255 − 16 = 239.
/// A longer episode title otherwise aborts the merge with `File name too long`
/// (errno 36) after the whole episode has already been downloaded.
const int kMaxDownloadNameBytes = 239;

extension StringExtensions on String {
  String substringAfter(String pattern) {
    final startIndex = indexOf(pattern);
    if (startIndex == -1) return substring(0);
    final start = startIndex + pattern.length;
    return substring(start);
  }

  String substringAfterLast(String pattern) {
    return split(pattern).last;
  }

  String substringBefore(String pattern) {
    final endIndex = indexOf(pattern);
    if (endIndex == -1) return substring(0);
    return substring(0, endIndex);
  }

  String substringBeforeLast(String pattern) {
    final endIndex = lastIndexOf(pattern);
    if (endIndex == -1) return substring(0);
    return substring(0, endIndex);
  }

  String substringBetween(String left, String right) {
    int startIndex = 0;
    int index = indexOf(left, startIndex);
    if (index == -1) return "";
    int leftIndex = index + left.length;
    int rightIndex = indexOf(right, leftIndex);
    if (rightIndex == -1) return "";
    startIndex = rightIndex + right.length;
    return substring(leftIndex, rightIndex);
  }

  String replaceForbiddenCharacters(String source) {
    return replaceAll(
      RegExp(r'[\\/:*?"<>|\0]|(^CON$|^PRN$|^AUX$|^NUL$|^COM[1-9]$|^LPT[1-9]$)'),
      source,
    );
  }

  /// Truncates this string so its UTF-8 encoding fits in [maxBytes], never
  /// splitting a rune. Apply it to a name *before* the extension is appended.
  String truncateToBytes(int maxBytes) {
    if (utf8.encode(this).length <= maxBytes) return this;
    var end = length;
    while (end > 0 && utf8.encode(substring(0, end)).length > maxBytes) {
      end--;
    }
    return substring(0, end);
  }

  String get getUrlWithoutDomain {
    // Some extensions store an opaque token in a chapter's `url` instead of a
    // real URL (see string_extensions_io.dart). `Uri.parse` throws on it, so
    // hand an unparseable value back unchanged rather than crashing the caller.
    final Uri uri;
    try {
      uri = Uri.parse(replaceAll(' ', '%20'));
    } catch (_) {
      return this;
    }
    String out = uri.path;
    if (uri.query.isNotEmpty) {
      out += '?${uri.query}';
    }
    if (uri.fragment.isNotEmpty) {
      out += '#${uri.fragment}';
    }
    return out;
  }

  /// True when this URL points at a progressive video file (`.mp4`, `.mkv`…).
  ///
  /// Matches the extension against the URL *path* only, after dropping the
  /// query, the fragment and any trailing slash. Signed CDN links append a
  /// token after the file name (`…/720p.mp4?token=…`, KVS serves
  /// `…/720p.mp4/?v-acctoken=…`), and testing `endsWith('mp4')` on the raw
  /// string rejected every one of them — the download then found "no playable
  /// URL" for a file it could have fetched. The extension must also be a real
  /// dotted extension, so a directory named `mov` is not mistaken for a movie.
  bool isMediaVideo() {
    var path = this;
    try {
      final uri = Uri.tryParse(this);
      path = uri != null && uri.hasScheme
          ? uri.path
          : split('?').first.split('#').first;
    } catch (_) {
      // Opaque chapter tokens are not URLs; fall through with the raw value.
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final lower = path.toLowerCase();
    return const [
      "3gp", "avi", "mpg", "mpeg", "webm", "ogg", "flv",
      "m4v", "mvp", "mp4", "wmv", "mkv", "mov",
    ].any((extension) => lower.endsWith('.$extension'));
  }
}

extension NativeStringExtensions on List<String> {
  List<String> strListToPointer() {
    return this;
  }
}
