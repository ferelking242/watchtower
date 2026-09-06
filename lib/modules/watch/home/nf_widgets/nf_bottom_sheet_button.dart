// Adapted from flutter_netflix — bottom_sheet_button.dart
// Added optional onTap callback.
import 'package:flutter/material.dart';
import 'nf_utils.dart';

class NfBottomSheetButton extends StatelessWidget {
  const NfBottomSheetButton({
    super.key,
    required this.icon,
    required this.label,
    this.light   = false,
    this.padding,
    this.size,
    this.onTap,
  });

  final IconData      icon;
  final String        label;
  final bool          light;
  final EdgeInsets?   padding;
  final double?       size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100.0),
      onTap:        onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100.0),
                color: light ? Colors.white : nfBottomSheetIconColor,
              ),
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Icon(
                icon,
                size:  size ?? 24.0,
                color: light ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              label,
              style:     const TextStyle(fontSize: 11.0),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
