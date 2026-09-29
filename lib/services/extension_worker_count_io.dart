import 'dart:io';

int getRecommendedExtensionWorkerCount() {
  final processors = Platform.numberOfProcessors;
  if (processors <= 1) return 1;
  return (processors - 1).clamp(1, 4).toInt();
}