// Copied verbatim from flutter_netflix — new_and_hot_tile_action.dart
import 'package:flutter/material.dart';

class NfNewAndHotTileAction extends StatelessWidget {
  const NfNewAndHotTileAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData      icon;
  final String        label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72.0, maxWidth: 72.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 20.0),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 12.0),
              Text(
                label,
                style:     const TextStyle(fontSize: 12.0),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
