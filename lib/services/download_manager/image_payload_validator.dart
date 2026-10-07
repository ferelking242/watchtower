import 'dart:convert';

/// Lightweight image integrity check used before reusing cached page files.
///
/// It checks common image signatures and their terminal markers without
/// decoding the whole image. Unknown image formats remain reusable when they
/// have a plausible size and do not look like an error page.
bool isReusableImagePayload({
  required int length,
  required List<int> prefix,
  required List<int> tail,
}) {
  if (length < 16 || prefix.isEmpty) return false;

  final text = utf8
      .decode(prefix.take(512).toList(), allowMalformed: true)
      .trimLeft()
      .toLowerCase();
  if (text.startsWith('<!doctype html') ||
      text.startsWith('<html') ||
      text.startsWith('<head') ||
      text.startsWith('{"error"') ||
      text.startsWith('{"message"') ||
      text.startsWith('access denied') ||
      text.startsWith('not found')) {
    return false;
  }

  bool startsWith(List<int> signature) {
    if (prefix.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (prefix[index] != signature[index]) return false;
    }
    return true;
  }

  bool endsWith(List<int> signature) {
    if (tail.length < signature.length) return false;
    final offset = tail.length - signature.length;
    for (var index = 0; index < signature.length; index++) {
      if (tail[offset + index] != signature[index]) return false;
    }
    return true;
  }

  const jpegSignature = [0xff, 0xd8, 0xff];
  if (startsWith(jpegSignature)) {
    return length >= 4 && endsWith(const [0xff, 0xd9]);
  }

  const pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (startsWith(pngSignature)) {
    return length >= 45 &&
        endsWith(const [
          0x00,
          0x00,
          0x00,
          0x00,
          0x49,
          0x45,
          0x4e,
          0x44,
          0xae,
          0x42,
          0x60,
          0x82,
        ]);
  }

  if (startsWith(const [0x47, 0x49, 0x46, 0x38])) {
    return length >= 14 && endsWith(const [0x3b]);
  }

  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      prefix.length >= 12 &&
      prefix[8] == 0x57 &&
      prefix[9] == 0x45 &&
      prefix[10] == 0x42 &&
      prefix[11] == 0x50) {
    final declaredLength =
        prefix[4] | (prefix[5] << 8) | (prefix[6] << 16) | (prefix[7] << 24);
    return length >= 16 && declaredLength + 8 <= length;
  }

  if (startsWith(const [0x42, 0x4d]) && prefix.length >= 6) {
    final declaredLength =
        prefix[2] | (prefix[3] << 8) | (prefix[4] << 16) | (prefix[5] << 24);
    return length >= 16 && (declaredLength == 0 || declaredLength <= length);
  }

  if (text.startsWith('<?xml') || text.startsWith('<svg')) {
    final tailText = utf8.decode(tail, allowMalformed: true).toLowerCase();
    return tailText.contains('</svg>');
  }

  return true;
}
