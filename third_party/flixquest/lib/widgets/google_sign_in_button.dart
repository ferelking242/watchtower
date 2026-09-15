import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canPress = enabled && !loading;
    return OutlinedButton.icon(
      onPressed: canPress ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      icon: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Icon(PhosphorIcons.googleLogo(), size: 22),
      label: Text(
        loading ? '' : tr('continue_with_google'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
