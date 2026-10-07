import 'package:flutter/material.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';

/// Full-screen interactive browser shown when a Cloudflare notification opens.
class CloudflareChallengeScreen extends StatefulWidget {
  const CloudflareChallengeScreen({
    required this.url,
    this.sourceName,
    this.sourceId,
    super.key,
  });

  final String url;
  final String? sourceName;
  final int? sourceId;

  @override
  State<CloudflareChallengeScreen> createState() =>
      _CloudflareChallengeScreenState();
}

class _CloudflareChallengeScreenState extends State<CloudflareChallengeScreen> {
  bool _closing = false;

  void _close({bool resolved = false}) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(widget.url)?.host;
    final sourceName = widget.sourceName?.trim();
    final title = sourceName != null && sourceName.isNotEmpty
        ? sourceName
        : host == null || host.isEmpty
        ? 'Challenge Cloudflare'
        : host;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: CloudflareBypassPanel(
          url: widget.url,
          sourceId: widget.sourceId,
          fullScreen: true,
          onResolved: () => _close(resolved: true),
          onClose: () => _close(),
        ),
      ),
    );
  }
}