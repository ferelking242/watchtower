// lib/modules/plugin/file_manager/models/file_filter_type.dart

enum FileFilterType { all, documents, images, audio, videos, archives }

extension FileFilterTypeX on FileFilterType {
  String get label {
    switch (this) {
      case FileFilterType.all: return 'Tout';
      case FileFilterType.documents: return 'Documents';
      case FileFilterType.images: return 'Images';
      case FileFilterType.audio: return 'Audio';
      case FileFilterType.videos: return 'Vidéos';
      case FileFilterType.archives: return 'Archives';
    }
  }
}

enum SortType {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
}

extension SortTypeX on SortType {
  String get label {
    switch (this) {
      case SortType.nameAsc:  return 'Nom A→Z';
      case SortType.nameDesc: return 'Nom Z→A';
      case SortType.dateAsc:  return 'Date ancien';
      case SortType.dateDesc: return 'Date récent';
      case SortType.sizeAsc:  return 'Taille petite';
      case SortType.sizeDesc: return 'Taille grande';
    }
  }
}
