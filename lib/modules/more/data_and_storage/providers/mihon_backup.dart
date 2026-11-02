import 'dart:convert';
import 'dart:typed_data';

/// Tolerant reader for Mihon / Tachiyomi `.tachibk` backups.
///
/// A Mihon backup is **not** a single protobuf message: it is a protobuf
/// *stream* produced by `BackupWriter` (see `BackupStream.kt`). Every manga is
/// written as a length-delimited field-1 entry, and the remaining fields
/// (categories, sources, preferences, extension stores) are written once at the
/// end. Because the whole file is a plain sequence of protobuf fields, a normal
/// `mergeFromCodedBufferReader` on a message that declares fields 1, 2 and 101
/// merges everything correctly — as long as the declared field numbers match
/// Mihon's schema exactly.
///
/// Mihon's schema is not what the old Watchtower `.proto` files assumed:
///  * `BackupManga.source` is a `Long` (the extension's stable source id), not
///    an `int32`; the generated Dart class cannot represent the high values.
///  * `BackupChapter.dateFetch`/`dateUpload` and `BackupManga.dateAdded` are
///    epoch-millisecond `Long`s, and `chapterNumber`/`lastChapterRead` are
///    `Float`/`Double`, which the `int32` proto fields corrupt.
///  * `BackupCategory` carries an explicit `id` (field 3) and manga reference
///    categories by *order* (field 2), so the two must be joined on `order`.
///
/// Rather than regenerate the `.pb.dart` classes (no `protoc` in CI), this file
/// reads the stream directly, field by field. Unknown fields are skipped, so a
/// newer Mihon schema cannot break the import.
class MihonBackup {
  MihonBackup({
    required this.mangas,
    required this.categories,
    required this.sources,
    required this.preferences,
    required this.sourcePreferences,
    required this.extensionStores,
  });

  final List<MihonManga> mangas;
  final List<MihonCategory> categories;
  final List<MihonSource> sources;
  final List<MihonPreference> preferences;
  final List<MihonSourcePreferences> sourcePreferences;
  final List<MihonExtensionStore> extensionStores;

  /// Reads a whole (already gunzipped) backup stream.
  static MihonBackup parse(Uint8List bytes) {
    final mangas = <MihonManga>[];
    final categories = <MihonCategory>[];
    final sources = <MihonSource>[];
    final preferences = <MihonPreference>[];
    final sourcePreferences = <MihonSourcePreferences>[];
    final extensionStores = <MihonExtensionStore>[];

    final reader = _ProtoReader(bytes);
    while (!reader.isAtEnd) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1: // backupManga (entry)
          mangas.add(MihonManga.parse(reader.readBytes(wire)));
          break;
        case 2: // backupCategories
          categories.add(MihonCategory.parse(reader.readBytes(wire)));
          break;
        case 101: // backupSources
          sources.add(MihonSource.parse(reader.readBytes(wire)));
          break;
        case 104: // backupPreferences
          preferences.add(MihonPreference.parse(reader.readBytes(wire)));
          break;
        case 105: // backupSourcePreferences
          sourcePreferences.add(
            MihonSourcePreferences.parse(reader.readBytes(wire)),
          );
          break;
        case 106: // backupExtensionStores
          extensionStores.add(MihonExtensionStore.parse(reader.readBytes(wire)));
          break;
        default:
          reader.skip(wire);
      }
    }

    return MihonBackup(
      mangas: mangas,
      categories: categories,
      sources: sources,
      preferences: preferences,
      sourcePreferences: sourcePreferences,
      extensionStores: extensionStores,
    );
  }
}

class MihonManga {
  MihonManga({
    required this.source,
    required this.url,
    required this.title,
    this.artist,
    this.author,
    this.description,
    this.genre = const [],
    this.status = 0,
    this.thumbnailUrl,
    this.dateAdded = 0,
    this.viewer = 0,
    this.viewerFlags,
    this.chapterFlags = 0,
    this.favorite = true,
    this.chapters = const [],
    this.categories = const [],
    this.tracking = const [],
    this.history = const [],
    this.notes = '',
    this.excludedScanlators = const [],
  });

  final int source;
  final String url;
  final String title;
  final String? artist;
  final String? author;
  final String? description;
  final List<String> genre;
  final int status;
  final String? thumbnailUrl;
  final int dateAdded;
  final int viewer;
  final int? viewerFlags;
  final int chapterFlags;
  final bool favorite;
  final List<MihonChapter> chapters;
  final List<int> categories; // category *order* values
  final List<MihonTracking> tracking;
  final List<MihonHistory> history;
  final String notes;
  final List<String> excludedScanlators;

  static MihonManga parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var source = 0;
    var url = '';
    var title = '';
    String? artist;
    String? author;
    String? description;
    final genre = <String>[];
    var status = 0;
    String? thumbnailUrl;
    var dateAdded = 0;
    var viewer = 0;
    int? viewerFlags;
    var chapterFlags = 0;
    var favorite = true;
    final chapters = <MihonChapter>[];
    final categories = <int>[];
    final tracking = <MihonTracking>[];
    final history = <MihonHistory>[];
    var notes = '';
    final excludedScanlators = <String>[];

    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          source = r.readVarint();
          break;
        case 2:
          url = r.readString();
          break;
        case 3:
          title = r.readString();
          break;
        case 4:
          artist = r.readString();
          break;
        case 5:
          author = r.readString();
          break;
        case 6:
          description = r.readString();
          break;
        case 7:
          genre.add(r.readString());
          break;
        case 8:
          status = r.readVarint();
          break;
        case 9:
          thumbnailUrl = r.readString();
          break;
        case 13:
          dateAdded = r.readVarint();
          break;
        case 14:
          viewer = r.readVarint();
          break;
        case 16:
          chapters.add(MihonChapter.parse(r.readBytes(wire)));
          break;
        case 17:
          // Repeated int32, packed by default in proto3.
          if (wire == 2) {
            categories.addAll(r.readPackedVarints());
          } else {
            categories.add(r.readVarint());
          }
          break;
        case 18:
          tracking.add(MihonTracking.parse(r.readBytes(wire)));
          break;
        case 100:
          favorite = r.readVarint() != 0;
          break;
        case 101:
          chapterFlags = r.readVarint();
          break;
        case 103:
          viewerFlags = r.readVarint();
          break;
        case 104:
          history.add(MihonHistory.parse(r.readBytes(wire)));
          break;
        case 108:
          excludedScanlators.add(r.readString());
          break;
        case 110:
          notes = r.readString();
          break;
        default:
          r.skip(wire);
      }
    }

    return MihonManga(
      source: source,
      url: url,
      title: title,
      artist: artist,
      author: author,
      description: description,
      genre: genre,
      status: status,
      thumbnailUrl: thumbnailUrl,
      dateAdded: dateAdded,
      viewer: viewer,
      viewerFlags: viewerFlags,
      chapterFlags: chapterFlags,
      favorite: favorite,
      chapters: chapters,
      categories: categories,
      tracking: tracking,
      history: history,
      notes: notes,
      excludedScanlators: excludedScanlators,
    );
  }
}

class MihonChapter {
  MihonChapter({
    required this.url,
    required this.name,
    this.scanlator,
    this.read = false,
    this.bookmark = false,
    this.lastPageRead = 0,
    this.dateFetch = 0,
    this.dateUpload = 0,
    this.chapterNumber = 0,
    this.sourceOrder = 0,
  });

  final String url;
  final String name;
  final String? scanlator;
  final bool read;
  final bool bookmark;
  final int lastPageRead;
  final int dateFetch;
  final int dateUpload;
  final double chapterNumber;
  final int sourceOrder;

  static MihonChapter parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var url = '';
    var name = '';
    String? scanlator;
    var read = false;
    var bookmark = false;
    var lastPageRead = 0;
    var dateFetch = 0;
    var dateUpload = 0;
    var chapterNumber = 0.0;
    var sourceOrder = 0;

    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          url = r.readString();
          break;
        case 2:
          name = r.readString();
          break;
        case 3:
          scanlator = r.readString();
          break;
        case 4:
          read = r.readVarint() != 0;
          break;
        case 5:
          bookmark = r.readVarint() != 0;
          break;
        case 6:
          lastPageRead = r.readVarint();
          break;
        case 7:
          dateFetch = r.readVarint();
          break;
        case 8:
          dateUpload = r.readVarint();
          break;
        case 9:
          chapterNumber = r.readFloat();
          break;
        case 10:
          sourceOrder = r.readVarint();
          break;
        default:
          r.skip(wire);
      }
    }

    return MihonChapter(
      url: url,
      name: name,
      scanlator: scanlator,
      read: read,
      bookmark: bookmark,
      lastPageRead: lastPageRead,
      dateFetch: dateFetch,
      dateUpload: dateUpload,
      chapterNumber: chapterNumber,
      sourceOrder: sourceOrder,
    );
  }
}

class MihonCategory {
  MihonCategory({
    required this.name,
    this.order = 0,
    this.id = 0,
    this.flags = 0,
  });

  final String name;
  final int order;
  final int id;
  final int flags;

  static MihonCategory parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var name = '';
    var order = 0;
    var id = 0;
    var flags = 0;
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          name = r.readString();
          break;
        case 2:
          order = r.readVarint();
          break;
        case 3:
          id = r.readVarint();
          break;
        case 100:
          flags = r.readVarint();
          break;
        default:
          r.skip(wire);
      }
    }
    return MihonCategory(name: name, order: order, id: id, flags: flags);
  }
}

class MihonSource {
  MihonSource({required this.name, required this.sourceId});

  final String name;
  final int sourceId;

  static MihonSource parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var name = '';
    var sourceId = 0;
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          name = r.readString();
          break;
        case 2:
          sourceId = r.readVarint();
          break;
        default:
          r.skip(wire);
      }
    }
    return MihonSource(name: name, sourceId: sourceId);
  }
}

class MihonHistory {
  MihonHistory({required this.url, required this.lastRead, this.readDuration = 0});

  final String url;
  final int lastRead;
  final int readDuration;

  static MihonHistory parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var url = '';
    var lastRead = 0;
    var readDuration = 0;
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          url = r.readString();
          break;
        case 2:
          lastRead = r.readVarint();
          break;
        case 3:
          readDuration = r.readVarint();
          break;
        default:
          r.skip(wire);
      }
    }
    return MihonHistory(url: url, lastRead: lastRead, readDuration: readDuration);
  }
}

class MihonTracking {
  MihonTracking({
    required this.syncId,
    this.mediaId = 0,
    this.mediaIdInt = 0,
    this.trackingUrl = '',
    this.title = '',
    this.lastChapterRead = 0,
    this.totalChapters = 0,
    this.score = 0,
    this.status = 0,
    this.startedReadingDate = 0,
    this.finishedReadingDate = 0,
    this.private = false,
  });

  final int syncId;
  final int mediaId;
  final int mediaIdInt;
  final String trackingUrl;
  final String title;
  final double lastChapterRead;
  final int totalChapters;
  final double score;
  final int status;
  final int startedReadingDate;
  final int finishedReadingDate;
  final bool private;

  static MihonTracking parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var syncId = 0;
    var mediaId = 0;
    var mediaIdInt = 0;
    var trackingUrl = '';
    var title = '';
    var lastChapterRead = 0.0;
    var totalChapters = 0;
    var score = 0.0;
    var status = 0;
    var startedReadingDate = 0;
    var finishedReadingDate = 0;
    var private = false;
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          syncId = r.readVarint();
          break;
        case 3:
          mediaIdInt = r.readVarint();
          break;
        case 4:
          trackingUrl = r.readString();
          break;
        case 5:
          title = r.readString();
          break;
        case 6:
          lastChapterRead = r.readFloat();
          break;
        case 7:
          totalChapters = r.readVarint();
          break;
        case 8:
          score = r.readFloat();
          break;
        case 9:
          status = r.readVarint();
          break;
        case 10:
          startedReadingDate = r.readVarint();
          break;
        case 11:
          finishedReadingDate = r.readVarint();
          break;
        case 12:
          private = r.readVarint() != 0;
          break;
        case 100:
          mediaId = r.readVarint();
          break;
        default:
          r.skip(wire);
      }
    }
    return MihonTracking(
      syncId: syncId,
      mediaId: mediaId,
      mediaIdInt: mediaIdInt,
      trackingUrl: trackingUrl,
      title: title,
      lastChapterRead: lastChapterRead,
      totalChapters: totalChapters,
      score: score,
      status: status,
      startedReadingDate: startedReadingDate,
      finishedReadingDate: finishedReadingDate,
      private: private,
    );
  }
}

class MihonPreference {
  MihonPreference({required this.key, required this.type, required this.value});

  final String key;

  /// One of `int`, `long`, `float`, `string`, `bool`, `stringSet`.
  final String type;
  final Object value;

  static MihonPreference parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var key = '';
    var type = 'string';
    Object value = '';
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          key = r.readString();
          break;
        case 2:
          final parsed = _parsePreferenceValue(r.readBytes(wire));
          type = parsed.$1;
          value = parsed.$2;
          break;
        default:
          r.skip(wire);
      }
    }
    return MihonPreference(key: key, type: type, value: value);
  }
}

class MihonSourcePreferences {
  MihonSourcePreferences({required this.sourceKey, required this.prefs});

  final String sourceKey;
  final List<MihonPreference> prefs;

  static MihonSourcePreferences parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var sourceKey = '';
    final prefs = <MihonPreference>[];
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          sourceKey = r.readString();
          break;
        case 2:
          prefs.add(MihonPreference.parse(r.readBytes(wire)));
          break;
        default:
          r.skip(wire);
      }
    }
    return MihonSourcePreferences(sourceKey: sourceKey, prefs: prefs);
  }
}

class MihonExtensionStore {
  MihonExtensionStore({
    this.indexUrl = '',
    this.name = '',
    this.signingKey = '',
  });

  final String indexUrl;
  final String name;
  final String signingKey;

  static MihonExtensionStore parse(Uint8List bytes) {
    final r = _ProtoReader(bytes);
    var indexUrl = '';
    var name = '';
    var signingKey = '';
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      switch (field) {
        case 1:
          indexUrl = r.readString();
          break;
        case 2:
          name = r.readString();
          break;
        case 5:
          signingKey = r.readString();
          break;
        default:
          r.skip(wire);
      }
    }
    return MihonExtensionStore(
      indexUrl: indexUrl,
      name: name,
      signingKey: signingKey,
    );
  }
}

/// Decodes Mihon's polymorphic `PreferenceValue`.
///
/// `PreferenceValue` is a `sealed class` written *without* `@ProtoOneOf`, so
/// kotlinx.serialization uses its generic polymorphic layout: field 1 is the
/// concrete serial name and field 2 is the concrete message, itself holding a
/// single field-1 value. Reading field 1 as the payload would decode every
/// preference as the class-name string.
(String, Object) _parsePreferenceValue(Uint8List bytes) {
  final r = _ProtoReader(bytes);
  var typeName = '';
  var payload = Uint8List(0);
  while (!r.isAtEnd) {
    final tag = r.readVarint();
    final field = tag >> 3;
    final wire = tag & 0x7;
    if (field == 1) {
      typeName = r.readString();
    } else if (field == 2) {
      payload = r.readBytes(wire);
    } else {
      r.skip(wire);
    }
  }
  return _decodePreferencePayload(typeName, payload);
}

(String, Object) _decodePreferencePayload(String typeName, Uint8List payload) {
  final r = _ProtoReader(payload);
  if (typeName.endsWith('StringSetPreferenceValue')) {
    final values = <String>[];
    while (!r.isAtEnd) {
      final tag = r.readVarint();
      final field = tag >> 3;
      final wire = tag & 0x7;
      if (field == 1) {
        values.add(r.readString());
      } else {
        r.skip(wire);
      }
    }
    return ('stringSet', values);
  }

  if (r.isAtEnd) return ('string', '');
  final tag = r.readVarint();
  final field = tag >> 3;
  final wire = tag & 0x7;
  if (field != 1) return ('string', '');

  if (typeName.endsWith('BooleanPreferenceValue')) {
    return ('bool', r.readVarint() != 0);
  }
  if (typeName.endsWith('IntPreferenceValue')) {
    return ('int', r.readVarint());
  }
  if (typeName.endsWith('LongPreferenceValue')) {
    return ('long', r.readVarint());
  }
  if (typeName.endsWith('FloatPreferenceValue')) {
    return ('float', r.readFloat());
  }
  if (typeName.endsWith('StringPreferenceValue')) {
    return ('string', r.readString());
  }
  // Unknown variant: fall back on the wire type so the value is not lost.
  switch (wire) {
    case 0:
      return ('long', r.readVarint());
    case 1:
      return ('double', r.readDouble());
    case 2:
      return ('string', r.readString());
    case 5:
      return ('float', r.readFloat());
  }
  return ('string', '');
}

/// Minimal protobuf wire reader.
class _ProtoReader {
  _ProtoReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isAtEnd => _offset >= _bytes.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_offset >= _bytes.length) {
        throw const FormatException('Truncated protobuf varint');
      }
      final byte = _bytes[_offset++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
      if (shift > 63) throw const FormatException('Malformed protobuf varint');
    }
    return result;
  }

  double readFloat() {
    _require(4);
    final view = ByteData.sublistView(_bytes, _offset, _offset + 4);
    _offset += 4;
    return view.getFloat32(0, Endian.little);
  }

  double readDouble() {
    _require(8);
    final view = ByteData.sublistView(_bytes, _offset, _offset + 8);
    _offset += 8;
    return view.getFloat64(0, Endian.little);
  }

  Uint8List readBytes(int wire) {
    if (wire != 2) {
      // Not length-delimited: consume the scalar and return nothing.
      skip(wire);
      return Uint8List(0);
    }
    final length = readVarint();
    _require(length);
    final slice = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return slice;
  }

  String readString() {
    final length = readVarint();
    _require(length);
    final slice = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    // Protobuf strings are UTF-8; `fromCharCodes` would mangle every non-ASCII
    // title, author, genre or category name.
    return utf8.decode(slice, allowMalformed: true);
  }

  List<int> readPackedVarints() {
    final bytes = readBytes(2);
    final r = _ProtoReader(bytes);
    final values = <int>[];
    while (!r.isAtEnd) {
      values.add(r.readVarint());
    }
    return values;
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        readVarint();
        break;
      case 1:
        _require(8);
        _offset += 8;
        break;
      case 2:
        final length = readVarint();
        _require(length);
        _offset += length;
        break;
      case 5:
        _require(4);
        _offset += 4;
        break;
      default:
        throw FormatException('Unsupported protobuf wire type $wire');
    }
  }

  void _require(int count) {
    if (_offset + count > _bytes.length) {
      throw const FormatException('Truncated protobuf message');
    }
  }
}
