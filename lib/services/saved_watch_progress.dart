class SavedWatchProgress {
  final Duration position;
  final DateTime? savedAt;

  const SavedWatchProgress({
    required this.position,
    this.savedAt,
  });
}