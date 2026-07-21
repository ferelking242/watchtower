import 'dart:io';
  import 'dart:typed_data';
  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  import 'package:path_provider/path_provider.dart';

  class IconCacheService {
    IconCacheService._();
    static final IconCacheService _instance = IconCacheService._();
    static IconCacheService get instance => _instance;

    final Map<String, Uint8List?> _mem = {};
    Directory? _cacheDir;

    Future<Directory> get cacheDir async {
      _cacheDir ??= Directory('${(await getApplicationDocumentsDirectory()).path}/icon_cache');
      await _cacheDir!.create(recursive: true);
      return _cacheDir!;
    }

    String _key(int? sourceId, String? iconUrl) =>
        'icon_${sourceId ?? 0}_${iconUrl?.hashCode ?? 0}';

    Future<Uint8List?> getIcon(int? sourceId, String? iconUrl) async {
      if (iconUrl == null || iconUrl.isEmpty) return null;
      final key = _key(sourceId, iconUrl);
      if (_mem.containsKey(key)) return _mem[key];
      try {
        final dir = await cacheDir;
        final file = File('${dir.path}/$key.png');
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          _mem[key] = bytes;
          return bytes;
        }
      } catch (_) {}
      try {
        final resp = await http
            .get(Uri.parse(iconUrl))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          _mem[key] = resp.bodyBytes;
          try {
            final dir = await cacheDir;
            await File('${dir.path}/$key.png').writeAsBytes(resp.bodyBytes);
          } catch (_) {}
          return resp.bodyBytes;
        }
      } catch (_) {}
      _mem[key] = null;
      return null;
    }
  }

  class ExtensionIconWidget extends StatefulWidget {
    final int? sourceId;
    final String? iconUrl;
    final double size;

    const ExtensionIconWidget({
      super.key,
      required this.sourceId,
      required this.iconUrl,
      this.size = 30,
    });

    @override
    State<ExtensionIconWidget> createState() => _ExtensionIconWidgetState();
  }

  class _ExtensionIconWidgetState extends State<ExtensionIconWidget> {
    Uint8List? _bytes;
    bool _loading = true;

    @override
    void initState() {
      super.initState();
      _load();
    }

    @override
    void didUpdateWidget(ExtensionIconWidget old) {
      super.didUpdateWidget(old);
      if (old.iconUrl != widget.iconUrl || old.sourceId != widget.sourceId) _load();
    }

    Future<void> _load() async {
      if (!mounted) return;
      setState(() => _loading = true);
      final bytes = await IconCacheService.instance
          .getIcon(widget.sourceId, widget.iconUrl);
      if (mounted) setState(() { _bytes = bytes; _loading = false; });
    }

    @override
    Widget build(BuildContext context) {
      if (_loading) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: const Center(child: Icon(Icons.extension_rounded, size: 14)),
        );
      }
      if (_bytes == null) {
        return Icon(Icons.extension_rounded,
            size: widget.size * 0.6, color: Theme.of(context).hintColor);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.memory(_bytes!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain),
      );
    }
  }
  