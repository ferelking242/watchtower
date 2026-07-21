import 'package:flutter/material.dart';

/// Web stub for [MusicDiscoveryScreen].
///
/// The Spotube music module uses native FFI packages (sqlite3, drift) that
/// cannot be compiled with dart2js.  On web the music feature shows a simple
/// "not available" message instead.
class MusicDiscoveryScreen extends StatelessWidget {
  final String? initialRoute;
  const MusicDiscoveryScreen({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Music is only available on mobile and desktop.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
