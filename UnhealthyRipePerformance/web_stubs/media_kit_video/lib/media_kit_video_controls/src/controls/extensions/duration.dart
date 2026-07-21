extension DurationExtensions on Duration {
  String label({Duration? reference}) {
    if ((reference?.inHours ?? inHours) > 0 || inHours > 0) {
      return '${inHours.toString().padLeft(2, '0')}:${(inMinutes % 60).toString().padLeft(2, '0')}:${(inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${inMinutes.toString().padLeft(2, '0')}:${(inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Duration clamp(Duration minVal, Duration maxVal) {
    if (this < minVal) return minVal;
    if (this > maxVal) return maxVal;
    return this;
  }
}
