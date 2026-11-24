import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reel/app.dart';
import 'package:reel/core/contract/ui_contract.dart';
import 'package:reel/core/host/reel_host.dart';

import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/reel/reel_local_transport.dart';
import 'package:watchtower/modules/watch/reel/reel_screen.dart';
import 'package:watchtower/remote/remote_api_handler.dart';
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/services/layout_registry.dart';

/// Entry point of the Reel shell inside Watchtower.
///
/// The extension decides which shell draws it: `"renderer": "reel"` in its
/// `ui-layouts/<slug>.json` mounts Reel, anything else keeps the historical
/// watch screens. Reel receives the extension id, its layout and a transport
/// bound to this app's container — no HTTP server involved.
class ReelHostScreen extends ConsumerStatefulWidget {
  const ReelHostScreen({
    super.key,
    required this.source,
    this.listId = '',
    this.startGifId,
    this.fallback,
  });

  final Source source;
  final String listId;
  final String? startGifId;

  /// Screen used when the extension does not declare the Reel renderer.
  /// Defaults to the vertical video list, which is what the `reel` route did
  /// before the shell existed.
  final Widget? fallback;

  @override
  ConsumerState<ReelHostScreen> createState() => _ReelHostScreenState();
}

class _ReelHostScreenState extends ConsumerState<ReelHostScreen> {
  UiLayout? _layout;
  Map<String, dynamic>? _layoutJson;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    UiLayout? layout;
    Map<String, dynamic>? json;
    try {
      await LayoutRegistry.instance.load(widget.source);
      if (widget.source.providesHome &&
          !LayoutRegistry.instance.has(widget.source)) {
        await LayoutDownloader.instance.download(widget.source);
      }
      final raw = await LayoutRegistry.instance.readJson(widget.source);
      if (raw != null) json = jsonDecode(raw) as Map<String, dynamic>;
      layout = LayoutRegistry.instance.get(widget.source);
    } catch (_) {
      layout = null;
    }
    if (!mounted) return;
    setState(() {
      _layout = layout;
      _layoutJson = json;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final layout = _layout;
    if (layout == null || !layout.isReel) {
      // Extensions that did not opt into the Reel renderer keep the historical
      // screens, so installing this build never changes how they behave.
      return widget.fallback ??
          ReelScreen(
            source: widget.source,
            listId: widget.listId,
            startGifId: widget.startGifId,
          );
    }

    final container = ProviderScope.containerOf(context, listen: false);
    final transport = ReelLocalTransport(
      RemoteApiHandler(container, allowNsfw: true),
      sourceId: widget.source.id?.toString(),
    );

    return ReelHostedApp(
      host: ReelHost(
        sourceId: widget.source.id.toString(),
        sourceName: widget.source.name ?? '',
        transport: transport,
        contract: _contractFor(layout, _layoutJson),
      ),
    );
  }

  /// Converts the extension layout into the contract Reel renders from.
  ///
  /// Only the shell-relevant keys cross over: renderer and capabilities. Reel
  /// has its own dock and player defaults, and a missing key must fall back to
  /// a working value rather than an empty screen.
  UiContract _contractFor(UiLayout layout, Map<String, dynamic>? json) {
    final capabilities = layout.capabilities.toJson();
    if (json != null && json['capabilities'] is Map) {
      capabilities.addAll(
        Map<String, dynamic>.from(json['capabilities'] as Map),
      );
    }
    return UiContract.fromJson({
      'schemaVersion': layout.schemaVersion,
      'renderer': 'reel',
      'capabilities': capabilities,
      'id': widget.source.name ?? 'reel',
      'name': widget.source.name ?? 'Reel',
    });
  }
}
