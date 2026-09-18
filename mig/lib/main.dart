import 'package:flutter/material.dart';
import 'screens/mig_shell.dart';

void main() {
  runApp(const MigPreviewApp());
}

class MigPreviewApp extends StatelessWidget {
  const MigPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6D5CE7),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Watchtower UI migration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: scheme.surface,
        cardTheme: CardThemeData(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: .45),
          margin: const EdgeInsets.only(bottom: 8),
        ),
      ),
      home: const MigShell(),
    );
  }
}