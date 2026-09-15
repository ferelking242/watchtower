bool shouldShowNextEpisodeTeaser({
  required double progress,
  required bool introDbLookupSettled,
  required bool hasIntroDbOutroTiming,
  required bool introDbOutroReached,
  double fallbackProgress = .95,
}) {
  if (hasIntroDbOutroTiming) return introDbOutroReached;
  if (!introDbLookupSettled) return false;
  return progress >= fallbackProgress;
}
