import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import 'package:watchtower/local_indexer/engine/watcher/android_media_store.dart';

/// iOS counterpart of [AndroidMediaStore].
///
/// iPhone and iPad have no shared filesystem a media player can walk: the
/// videos live in the Photos library and the music in the iPod (MediaPlayer)
/// library, both behind their own permission and both exposed only through
/// system APIs. Walking the app's Documents folder — the only thing the Smart
/// Library used to do on iOS — therefore found nothing but files the user had
/// explicitly copied into Watchtower, which is why the library looked empty on
/// an iPhone that clearly had videos.
///
/// This bridge feeds the same [MediaStoreEntry] rows the Android bridge does,
/// so the indexer treats both platforms identically.
class IosMediaLibrary {
  IosMediaLibrary._();

  /// True when running on iOS, where these APIs exist.
  static bool get isAvailable => !kIsWeb && Platform.isIOS;

  /// Asks for read access to the Photos library, returning false when the
  /// user declines. Videos are the only asset type requested: asking for
  /// photos too would surface every screenshot in the scan.
  static Future<bool> requestPhotoAccess() async {
    if (!isAvailable) return false;
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          iosAccessLevel: IosAccessLevel.readWrite,
        ),
      );
      return permission.isAuth || permission.hasAccess;
    } catch (error) {
      debugPrint('[IosMediaLibrary] photo permission failed: $error');
      return false;
    }
  }

  /// Every video in the Photos library, as MediaStore-shaped rows.
  ///
  /// [AssetEntity.file] copies an iCloud-only asset down to a temporary file,
  /// which would download the whole library. Assets without a local file are
  /// skipped, exactly like a cloud track is skipped on the music side.
  static Future<List<MediaStoreEntry>> queryVideos() async {
    if (!isAvailable) return const [];
    final entries = <MediaStoreEntry>[];
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );
      const pageSize = 200;
      for (final album in albums) {
        final count = await album.assetCountAsync;
        for (var start = 0; start < count; start += pageSize) {
          final assets = await album.getAssetListRange(
            start: start,
            end: (start + pageSize).clamp(0, count),
          );
          for (final asset in assets) {
            if (asset.duration <= 0) continue;
            // Reading `file` on an iCloud-only asset downloads it; a library
            // kept in the cloud would be pulled down entirely by a scan.
            if (!await asset.isLocallyAvailable()) continue;
            final file = await asset.file;
            if (file == null) continue;
            final stat = await file.stat();
            entries.add(
              MediaStoreEntry(
                path: file.path,
                size: stat.size,
                modifiedAt: asset.modifiedDateTime.millisecondsSinceEpoch,
                // The basename keeps the container extension; a Photos title
                // such as "IMG_1234" has none and would be filtered out.
                displayName: p.basename(file.path),
                duration: asset.duration * 1000,
              ),
            );
          }
        }
      }
    } catch (error) {
      debugPrint('[IosMediaLibrary] video query failed: $error');
    }
    return entries;
  }

  /// Every track in the iPod library, as MediaStore-shaped rows.
  ///
  /// The platform already parsed title/artist/album from each file, and those
  /// tags beat anything guessed from a filename, so they are carried through.
  static Future<List<MediaStoreEntry>> queryAudio() async {
    if (!isAvailable) return const [];
    final entries = <MediaStoreEntry>[];
    try {
      final query = OnAudioQuery();
      if (!await query.permissionsStatus()) {
        if (!await query.permissionsRequest()) return const [];
      }
      final songs = await query.querySongs();
      for (final song in songs) {
        final path = song.data;
        if (path.isEmpty) continue;
        entries.add(
          MediaStoreEntry(
            path: path,
            size: song.size,
            modifiedAt: 0,
            // SongModel.title is the tag, not a filename, so it carries no
            // extension — the basename does, and the extension gate needs it.
            displayName: p.basename(path),
            duration: song.duration,
            title: song.title,
            artist: song.artist,
            album: song.album,
          ),
        );
      }
    } catch (error) {
      debugPrint('[IosMediaLibrary] audio query failed: $error');
    }
    return entries;
  }
}
