import 'dart:ui';
import 'package:flutter/material.dart';

class MediaIndicatorBuilder extends StatelessWidget {
  final bool isVolumeIndicator;
  final ValueNotifier<double> value;
  const MediaIndicatorBuilder({
    super.key,
    required this.value,
    required this.isVolumeIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: value,
      builder: (context, val, child) {
        final icon = isVolumeIndicator
            ? switch (val) {
                == 0.0 => Icons.volume_off,
                < 0.5 => Icons.volume_down_rounded,
                _ => Icons.volume_up_rounded,
              }
            : switch (val) {
                < 1.0 / 3.0 => Icons.brightness_low_rounded,
                < 2.0 / 3.0 => Icons.brightness_medium_rounded,
                _ => Icons.brightness_high_rounded,
              };
        final pct = (val * 100).round();
        return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 26),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 80,
                        width: 6,
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: LinearProgressIndicator(
                            value: val,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        );
      },
    );
  }
}
