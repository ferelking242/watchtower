class Picture {
  final String? mimeType;
  final List<int>? data;
  const Picture({this.mimeType, this.data});
}
class Metadata {
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? trackNumber;
  final int? trackTotal;
  final int? discNumber;
  final int? discTotal;
  final Object? year;
  final String? genre;
  final String? comment;
  final num? durationMs;
  final int? bitrate;
  final int? sampleRate;
  final int? channels;
  final BigInt? fileSize;
  final Picture? picture;
  const Metadata({this.title, this.artist, this.albumArtist, this.album, this.trackNumber, this.trackTotal, this.discNumber, this.discTotal, this.year, this.genre, this.comment, this.durationMs, this.bitrate, this.sampleRate, this.channels, this.fileSize, this.picture});
}
class MetadataGod {
  static Future<void> initialize() async {}
  static Future<Metadata> readMetadata({required String file, bool getImage = false}) async => const Metadata();
  static Future<void> writeMetadata({required String file, required Metadata metadata}) async {}
}
