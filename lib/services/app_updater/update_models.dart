/// Plain data handed to the update UI.
///
/// Screens never import `app_updater`: the package reads files and installs
/// native packages, so it is not compiled for the web target. These models
/// keep the same shape on both targets.
class UpdateInfoView {
  const UpdateInfoView({
    required this.currentVersion,
    this.latestVersion,
    this.releaseNotes,
    this.sizeBytes,
    this.publishedAt,
    this.updateAvailable = false,
    this.phase = 'idle',
    this.progress,
    this.error,
  });

  final String currentVersion;
  final String? latestVersion;
  final String? releaseNotes;
  final int? sizeBytes;
  final DateTime? publishedAt;
  final bool updateAvailable;

  /// `idle`, `checking`, `available`, `downloading`, `readyToInstall`,
  /// `installing`, `installed`, `upToDate` or `failed`.
  final String phase;

  /// 0..1 while downloading.
  final double? progress;
  final Object? error;

  bool get isDownloading => phase == 'downloading' || phase == 'checking';
  bool get isReady => phase == 'readyToInstall' || phase == 'installed';

  UpdateInfoView copyWith({
    String? currentVersion,
    String? latestVersion,
    String? releaseNotes,
    int? sizeBytes,
    DateTime? publishedAt,
    bool? updateAvailable,
    String? phase,
    double? progress,
    Object? error,
  }) {
    return UpdateInfoView(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      publishedAt: publishedAt ?? this.publishedAt,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

/// One past release, shown in the history section of the update page.
class UpdateHistoryEntry {
  const UpdateHistoryEntry({
    required this.version,
    this.publishedAt,
    this.notes,
    this.isCurrent = false,
  });

  final String version;
  final DateTime? publishedAt;
  final String? notes;
  final bool isCurrent;
}
