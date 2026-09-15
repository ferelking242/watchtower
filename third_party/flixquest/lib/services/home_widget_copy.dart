/// Every string that reaches an Android home screen widget is composed here.
///
/// A widget has five slots — eyebrow, title, subtitle, progress bar, meta — and the rule that keeps
/// them readable is that no two slots may carry the same fact. Building the copy in one place is
/// what makes that rule checkable, and it leaves the Kotlin side with no strings of its own to drift
/// out of sync with.
class HomeWidgetCopy {
  const HomeWidgetCopy._();

  /// Separates two facts sharing one slot.
  static const String separator = '  ·  ';

  static const int weekLength = 7;

  /// Subtitle of a daily pick: "2024  ·  8.1 rating".
  static String dailyFacts({String? date, num? rating}) => _join([
        _year(date),
        if (rating != null && rating > 0) '${rating.toStringAsFixed(1)} rating',
      ]);

  /// Meta of a daily pick. The synopsis is the one thing a poster cannot tell you, cut to what
  /// fits two lines.
  static String hook(String? overview) => _ellipsize(overview, 108);

  /// "3h 20m", "45m", "2h".
  static String duration(int milliseconds) {
    final minutes = (milliseconds / Duration.millisecondsPerMinute).round();
    if (minutes < 1) return 'under a minute';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '${remainder}m';
    if (remainder == 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }

  /// Title of the insights widget.
  static String weekTotal(int totalWatchedMs) => totalWatchedMs <= 0
      ? 'No viewing yet'
      : '${duration(totalWatchedMs)} watched';

  /// Subtitle of the insights widget. It labels the bar directly beneath it, and is the only place
  /// the day count is written out. With nothing to count it states where the numbers come from
  /// rather than restating the empty total already in the title.
  static String weekActivity(int activeDays) => activeDays <= 0
      ? 'Counted only on this device'
      : '$activeDays of $weekLength days active';

  /// The bar under [weekActivity], as a percentage of the week.
  static int weekProgress(int activeDays) =>
      ((activeDays.clamp(0, weekLength) / weekLength) * 100).round();

  /// Meta of the insights widget: "3 titles finished  ·  Top genre: Sci-Fi".
  static String weekHighlights(
          {required int completedTitles, String? topGenre}) =>
      _join([
        if (completedTitles > 0)
          '$completedTitles ${_plural(completedTitles, 'title')} finished',
        if (topGenre != null && topGenre.trim().isNotEmpty)
          'Top genre: ${topGenre.trim()}',
      ]);

  /// Subtitle of the continue-watching widget: which episode, or the year of a film. Never the
  /// viewing status, which the bar and [remaining] already convey between them.
  static String episodeFacts({
    required bool isEpisode,
    int? season,
    int? episode,
    String? episodeTitle,
    int? releaseYear,
  }) {
    if (!isEpisode) return (releaseYear ?? 0) <= 0 ? '' : '$releaseYear';
    // Absent season and episode numbers arrive as zero rather than null.
    final number = switch ((_positive(season), _positive(episode))) {
      (final int s, final int e) => 'S$s E$e',
      (final int s, null) => 'Season $s',
      (null, final int e) => 'Episode $e',
      _ => '',
    };
    return _join([number, episodeTitle?.trim() ?? '']);
  }

  /// Meta of the continue-watching widget. The bar carries the ratio, so this is the absolute
  /// figure and nothing else: "18m left".
  static String remaining({
    required int durationMs,
    required int progressEndMs,
    required bool completed,
  }) {
    if (completed) return 'Finished — worth another look';
    final left = durationMs - progressEndMs;
    if (durationMs <= 0 || left <= 0) return '';
    return '${duration(left)} left';
  }

  /// Eyebrow of the list widget, where the total belongs so no other slot has to repeat it.
  static String listEyebrow(int saved) =>
      saved <= 0 ? 'MY LIST' : 'MY LIST$separator$saved SAVED';

  /// Subtitle of the list widget: "7 movies  ·  5 TV shows", dropping an empty side.
  static String listBreakdown({required int movies, required int tvShows}) =>
      _join([
        if (movies > 0) '$movies ${_plural(movies, 'movie')}',
        if (tvShows > 0) '$tvShows ${_plural(tvShows, 'TV show')}',
      ]);

  /// Meta of the list widget, describing the one title whose poster is on screen.
  static String titleFacts({required bool isMovie, String? date}) => _join([
        isMovie ? 'Movie' : 'TV show',
        _year(date),
      ]);

  static String _join(Iterable<String> parts) =>
      parts.where((part) => part.isNotEmpty).join(separator);

  static String _plural(int count, String noun) =>
      count == 1 ? noun : '${noun}s';

  static int? _positive(int? value) =>
      value != null && value > 0 ? value : null;

  static String _year(String? date) {
    final parsed = date == null ? null : DateTime.tryParse(date);
    return parsed == null ? '' : '${parsed.year}';
  }

  /// Cuts at a word boundary so the widget never shows half a word before the ellipsis.
  static String _ellipsize(String? value, int limit) {
    final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (text.length <= limit) return text;
    final cut = text.substring(0, limit);
    final lastSpace = cut.lastIndexOf(' ');
    return '${(lastSpace > limit ~/ 2 ? cut.substring(0, lastSpace) : cut).trimRight()}…';
  }
}
