// Web stub — no Isar, no dart:io.
// Mirrors the public API of transfer_library_io.dart.
import 'transfer_models.dart';

class LibraryEntry {
  final String name;
  final String? imageUrl;
  final TransferItemType itemType;
  final List<LibraryChapter> chapters;
  const LibraryEntry({
    required this.name,
    this.imageUrl,
    required this.itemType,
    required this.chapters,
  });
}

class LibraryChapter {
  final String id;
  final String name;
  final String localPath;
  final int size;
  final TransferItemType type;
  const LibraryChapter({
    required this.id,
    required this.name,
    required this.localPath,
    required this.size,
    required this.type,
  });

  TransferFile toTransferFile() => TransferFile(
        id: id,
        name: name,
        size: size,
        type: type,
        localPath: localPath,
      );
}

Future<List<LibraryEntry>> loadLibraryDownloads() async => const [];
