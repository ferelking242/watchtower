import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';

/// Bottom-sheet wrapper around the shared inline [CloudflareBypassPanel].
/// Pops with `true` as soon as the challenge is resolved.
class BypassWebViewSheet extends StatefulWidget {
  final String url;
  const BypassWebViewSheet({super.key, required this.url});

  @override
  State<BypassWebViewSheet> createState() => _BypassWebViewSheetState();
}

class _BypassWebViewSheetState extends State<BypassWebViewSheet> {
  void _resolved() {
    if (!mounted) return;
    try {
      botToast('✅ Cloudflare résolu — accès rétabli', second: 4);
    } catch (_) {}
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Thin sheet handle
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: CloudflareBypassPanel(
            url: widget.url,
            compact: false,
            onResolved: _resolved,
            onClose: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    );
  }
}
