import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Release-mode replacement for Flutter's [ErrorWidget].
///
/// A widget that throws during build normally renders a bare grey box with no
/// text in release builds. To the user the app looks frozen on an empty
/// screen, and there is no hint that pressing back would recover. This view
/// keeps the message readable and gives the navigation bar something to
/// replace, so a single broken widget costs one screen instead of the session.
///
/// It is deliberately dependency-free: no [Theme], no [Directionality]
/// ancestor, no localization delegate — those are exactly what can be missing
/// when a subtree fails to build.
class FriendlyErrorView extends StatelessWidget {
  const FriendlyErrorView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF121212),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Color(0xFFFFB74D),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Something went wrong on this screen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Go back and try again. The rest of the app keeps working.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                ),
                if (kDebugMode && message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEF9A9A),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
