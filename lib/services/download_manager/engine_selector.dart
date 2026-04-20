import 'package:watchtower/models/manga.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';

/// Decides which download engine to use based on mode settings and URL type.
class EngineSelector {
  static SelectedEngine select({
    required String url,
    required ItemType itemType,
    required DownloadMode mode,
    bool hasFailed = false,
    int retryCount = 0,
  }) {
    // Fallback mode: switch to ZeusDL after first failure
    if (mode == DownloadMode.internalFallback && hasFailed) {
      return SelectedEngine.zeusDl;
    }

    // Explicit ZeusDL mode
    if (mode == DownloadMode.zeusDl) {
      return SelectedEngine.zeusDl;
    }

    // Auto mode: intelligent selection
    if (mode == DownloadMode.auto) {
      return _autoSelect(url, itemType, hasFailed, retryCount);
    }

    // internalDownloader: always use internal HLS
    return SelectedEngine.internal;
  }

  static SelectedEngine _autoSelect(
    String url,
    ItemType itemType,
    bool hasFailed,
    int retryCount,
  ) {
    final lower = url.toLowerCase();

    final isProtectedStream =
        lower.contains('token=') ||
        lower.contains('sig=') ||
        lower.contains('expires=') ||
        lower.contains('hmac=') ||
        _isProtectedDomain(lower);

    if (itemType == ItemType.anime && isProtectedStream) {
      return SelectedEngine.zeusDl;
    }

    if (hasFailed && retryCount >= 1) {
      return SelectedEngine.zeusDl;
    }

    return SelectedEngine.internal;
  }

  static bool _isProtectedDomain(String url) {
    const protectedDomains = [
      'crunchyroll.com',
      'funimation.com',
      'hidive.com',
      'vrv.co',
      'wakanim.tv',
    ];
    return protectedDomains.any((d) => url.contains(d));
  }
}

enum SelectedEngine { internal, zeusDl }

extension SelectedEngineExt on SelectedEngine {
  String get badgeLabel {
    switch (this) {
      case SelectedEngine.internal:
        return 'HLS';
      case SelectedEngine.zeusDl:
        return 'ZDL';
    }
  }

  String get fullName {
    switch (this) {
      case SelectedEngine.internal:
        return 'Interne HLS';
      case SelectedEngine.zeusDl:
        return 'ZeusDL';
    }
  }
}
