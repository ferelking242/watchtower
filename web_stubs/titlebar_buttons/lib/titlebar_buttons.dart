
import 'package:flutter/material.dart';
enum ThemeType { auto, dark, light }
class DecoratedMinimizeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final ThemeType? type;
  const DecoratedMinimizeButton({super.key, this.onPressed, this.type});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class DecoratedMaximizeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final ThemeType? type;
  const DecoratedMaximizeButton({super.key, this.onPressed, this.type});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
class DecoratedCloseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final ThemeType? type;
  const DecoratedCloseButton({super.key, this.onPressed, this.type});
  @override Widget build(BuildContext context) => const SizedBox.shrink();
}
