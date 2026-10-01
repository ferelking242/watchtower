import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/services/layout_registry.dart';

class LayoutJsonEditorScreen extends StatefulWidget {
  final Source source;
  final String? initialContent;
  final Future<void> Function()? onSaved;

  const LayoutJsonEditorScreen({
    super.key,
    required this.source,
    this.initialContent,
    this.onSaved,
  });

  @override
  State<LayoutJsonEditorScreen> createState() => _LayoutJsonEditorScreenState();
}

class _LayoutJsonEditorScreenState extends State<LayoutJsonEditorScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLayout());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLayout() async {
    try {
      var content =
          widget.initialContent ??
          await LayoutRegistry.instance.readJson(widget.source);
      if (content == null) {
        final downloaded =
            await LayoutDownloader.instance.download(widget.source);
        if (downloaded) {
          content = await LayoutRegistry.instance.readJson(widget.source);
        }
      }
      final formatted = content == null ? null : _formatJson(content);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (formatted == null) {
          _message =
              'Aucun layout JSON n’est disponible pour cette extension.';
          _messageIsError = true;
        } else {
          _controller.text = formatted;
          _message = null;
          _messageIsError = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Impossible de charger le layout : $error';
        _messageIsError = true;
      });
    }
  }

  String _formatJson(String source) {
    final decoded = jsonDecode(source);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  Future<void> _saveLayout() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('La racine JSON doit être un objet.');
      }
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      final saved = await LayoutRegistry.instance.save(
        widget.source,
        formatted,
      );
      if (!saved) {
        throw const FormatException(
          'Le layout ne respecte pas le schéma attendu.',
        );
      }
      if (!mounted) return;
      setState(() {
        _controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
        _message = 'Layout enregistré sur cet appareil.';
        _messageIsError = false;
      });
      final onSaved = widget.onSaved;
      if (onSaved != null) await onSaved();
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'JSON invalide : ${error.message}';
        _messageIsError = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Enregistrement impossible : $error';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Layout JSON · ${widget.source.name ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer le layout',
            onPressed: _loading || _saving ? null : _saveLayout,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Modifie librement le JSON. Les changements sont enregistrés '
                'localement et remplacent le layout affiché par Watchtower '
                'sur cet appareil.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError ? colors.error : colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TextField(
                        controller: _controller,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.45,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(14),
                          hintText: 'Le JSON du layout apparaîtra ici',
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading || _saving ? null : _saveLayout,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}