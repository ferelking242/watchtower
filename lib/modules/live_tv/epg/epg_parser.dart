import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml_events.dart';

import 'package:watchtower/modules/live_tv/epg/epg_models.dart';

/// Streaming XMLTV reader.
///
/// Real guides are large: the French XMLTV file is 76 MB of XML and expands to
/// over a gigabyte of event objects if parsed as a DOM. This walks the byte
/// stream with `xml_events` instead, keeping only the fields it needs, so peak
/// memory stays proportional to the guide's channel count rather than its
/// programme count.
///
/// Accepts gzip and plain bodies, because a guide URL may serve either.
class EpgParser {
  EpgParser({this.onProgress});

  /// Called with the number of programmes read so far, for a progress bar.
  final void Function(int programmes)? onProgress;

  /// Parses [bytes] into a guide. [source] is kept for display only.
  Future<EpgGuide> parseBytes(
    Uint8List bytes, {
    required String source,
    int? maxProgrammes,
  }) async {
    final xmlBytes = _maybeGunzip(bytes);
    final channels = <String, EpgChannel>{};
    final programmes = <String, List<EpgProgramme>>{};

    // Parser state: which element we are inside, and the text collected for it.
    String? channelId;
    final names = <String>[];
    String? icon;
    String? country;

    EpgProgramme? pending;
    var field = '';
    final buffer = StringBuffer();
    var count = 0;

    void flushChannel() {
      if (channelId == null) return;
      channels[channelId!] = EpgChannel(
        id: channelId!,
        names: names.isEmpty ? [channelId!] : List.of(names),
        iconUrl: icon,
        country: country,
      );
      channelId = null;
      names.clear();
      icon = null;
      country = null;
    }

    void flushProgramme() {
      final programme = pending;
      if (programme == null) return;
      programmes.putIfAbsent(programme.channelId, () => []).add(programme);
      pending = null;
      count++;
      if (count % 5000 == 0) onProgress?.call(count);
    }

    final stream = Stream<List<int>>.value(
      xmlBytes,
    ).transform(utf8.decoder).toXmlEvents();

    await for (final events in stream) {
      for (final event in events) {
        if (event is XmlStartElementEvent) {
          final attributes = {
            for (final attribute in event.attributes)
              attribute.name: attribute.value,
          };
          switch (event.name) {
            case 'channel':
              flushChannel();
              channelId = attributes['id'];
            case 'programme':
              flushProgramme();
              final start = _parseTime(attributes['start']);
              final stop = _parseTime(attributes['stop']);
              final id = attributes['channel'];
              if (start != null &&
                  stop != null &&
                  id != null &&
                  stop.isAfter(start)) {
                pending = EpgProgramme(
                  channelId: id,
                  title: '',
                  start: start,
                  stop: stop,
                  episode: attributes['episode-num'] ?? attributes['episode'],
                );
              } else {
                pending = null;
              }
            case 'display-name':
            case 'title':
            case 'desc':
            case 'category':
              field = event.name;
              buffer.clear();
            case 'icon':
              if (channelId != null && icon == null) {
                icon = attributes['src'];
              }
            case 'country':
              field = event.name;
              buffer.clear();
          }
          if (maxProgrammes != null && count >= maxProgrammes) break;
        } else if (event is XmlTextEvent) {
          if (field.isNotEmpty) buffer.write(event.value);
        } else if (event is XmlCDATAEvent) {
          if (field.isNotEmpty) buffer.write(event.value);
        } else if (event is XmlEndElementEvent) {
          switch (event.name) {
            case 'display-name':
              if (channelId != null && buffer.isNotEmpty) {
                names.add(buffer.toString().trim());
              }
              field = '';
            case 'title':
              final programme = pending;
              if (programme != null && buffer.isNotEmpty) {
                pending = EpgProgramme(
                  channelId: programme.channelId,
                  title: buffer.toString().trim(),
                  start: programme.start,
                  stop: programme.stop,
                  description: programme.description,
                  category: programme.category,
                  episode: programme.episode,
                );
              }
              field = '';
            case 'desc':
              final programme = pending;
              if (programme != null && buffer.isNotEmpty) {
                pending = EpgProgramme(
                  channelId: programme.channelId,
                  title: programme.title,
                  start: programme.start,
                  stop: programme.stop,
                  description: buffer.toString().trim(),
                  category: programme.category,
                  episode: programme.episode,
                );
              }
              field = '';
            case 'category':
              final programme = pending;
              if (programme != null && buffer.isNotEmpty) {
                pending = EpgProgramme(
                  channelId: programme.channelId,
                  title: programme.title,
                  start: programme.start,
                  stop: programme.stop,
                  description: programme.description,
                  category: buffer.toString().trim(),
                  episode: programme.episode,
                );
              }
              field = '';
            case 'country':
              if (channelId != null && buffer.isNotEmpty) {
                country = buffer.toString().trim();
              }
              field = '';
            case 'programme':
              flushProgramme();
            case 'channel':
              flushChannel();
          }
        }
      }
      if (maxProgrammes != null && count >= maxProgrammes) break;
    }
    flushProgramme();
    flushChannel();

    // A programme whose <title> arrived after <programme> closed is dropped:
    // an untitled slot cannot be shown, and keeping it would only pad the grid.
    for (final list in programmes.values) {
      list.removeWhere((programme) => programme.title.isEmpty);
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    onProgress?.call(count);
    return EpgGuide(
      channels: channels,
      programmes: programmes,
      source: source,
      fetchedAt: DateTime.now(),
    );
  }

  static Uint8List _maybeGunzip(Uint8List bytes) {
    // gzip magic: 0x1f 0x8b. Some servers omit the header on an unzipped body.
    if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        final decoded = GZipDecoder().decodeBytes(bytes);
        return Uint8List.fromList(decoded);
      } catch (_) {
        return bytes;
      }
    }
    return bytes;
  }

  /// Parses `20261120143000 +0100`, `20261120143000` and `2026-11-20T14:30:00Z`.
  static DateTime? _parseTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    final iso = DateTime.tryParse(value);
    if (iso != null) return iso.toLocal();

    // XMLTV compact form: 14 digits, optionally followed by a zone.
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*(.*)$',
    ).firstMatch(value);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4)!);
    final minute = int.tryParse(match.group(5)!);
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;
    if (year == null || month == null || day == null) return null;
    if (hour == null || minute == null) return null;

    var moment = DateTime.utc(year, month, day, hour, minute, second);
    final zone = match.group(7)?.trim() ?? '';
    final offset = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(zone);
    if (offset != null) {
      final hours = int.parse(offset.group(2)!);
      final minutes = int.parse(offset.group(3)!);
      final delta = Duration(hours: hours, minutes: minutes);
      moment = offset.group(1) == '-'
          ? moment.add(delta)
          : moment.subtract(delta);
    }
    return moment.toLocal();
  }
}
