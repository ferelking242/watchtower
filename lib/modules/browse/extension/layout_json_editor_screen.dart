import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/services/layout_registry.dart';

/// Éditeur JSON du layout : options de vue (taille du texte, retour à la
/// ligne, formatage/minification) et d'alignement (gauche / centre).
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

enum _JsonTextSize { small, medium, large }

enum _JsonAlignment { left, center }

class _LayoutJsonEditorScreenState extends State<LayoutJsonEditorScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // ── Options de vue ──
  _JsonTextSize _textSize = _JsonTextSize.medium;
  bool _wrapLines = true;
  _JsonAlignment _alignment = _JsonAlignment.left;
  bool _showLineNumbers = false;

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
    _focusNode.dispose();
    super.dispose();
  }

  double get _editorFontSize => switch (_textSize) {
        _JsonTextSize.small => 11.5,
        _JsonTextSize.medium => 13,
        _JsonTextSize.large => 15.5,
      };

  Future<void> _loadLayout() async {
    try {
      var content =
          widget.initialContent ?? await LayoutRegistry.instance.readJson(widget.source);
      if (content == null) {
        final downloaded = await LayoutDownloader.instance.download(widget.source);
        if (downloaded) {
          content = await LayoutRegistry.instance.readJson(widget.source);
        }
      }
      final formatted = content == null ? null : _formatJson(content);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (formatted == null) {
          _message = 'Aucun layout JSON n’est disponible pour cette extension.';
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
      final saved = await LayoutRegistry.instance.save(widget.source, formatted);
      if (!saved) {
        throw const FormatException('Le layout ne respecte pas le schéma attendu.');
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

  void _reformat() {
    try {
      final decoded = jsonDecode(_controller.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      setState(() {
        _controller.value = TextEditingValue(
          text: formatted,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _message = null;
        _messageIsError = false;
      });
    } catch (error) {
      setState(() {
        _message = 'JSON invalide : $error';
        _messageIsError = true;
      });
    }
  }

  void _minify() {
    try {
      final decoded = jsonDecode(_controller.text);
      final minified = jsonEncode(decoded);
      setState(() {
        _controller.value = TextEditingValue(
          text: minified,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _message = null;
        _messageIsError = false;
      });
    } catch (error) {
      setState(() {
        _message = 'JSON invalide : $error';
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B11),
        title: Text(
          'Layout JSON · ${widget.source.name ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Formater (indenté)',
            onPressed: _loading ? null : _reformat,
            icon: const Icon(Icons.data_object_rounded),
          ),
          IconButton(
            tooltip: 'Minifier',
            onPressed: _loading ? null : _minify,
            icon: const Icon(Icons.code_rounded),
          ),
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
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditorOptionsBar(
              textSize: _textSize,
              onTextSizeChanged: (size) => setState(() => _textSize = size),
              wrapLines: _wrapLines,
              onWrapLinesChanged: (value) => setState(() => _wrapLines = value),
              alignment: _alignment,
              onAlignmentChanged: (value) => setState(() => _alignment = value),
              showLineNumbers: _showLineNumbers,
              onShowLineNumbersChanged: (value) =>
                  setState(() => _showLineNumbers = value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Les changements sont enregistrés localement et remplacent le '
                'layout affiché par Watchtower sur cet appareil.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError ? colors.error : colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF12161C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .08),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_showLineNumbers) _LineNumbersGutter(controller: _controller),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                expands: true,
                                minLines: null,
                                maxLines: _wrapLines ? null : 1,
                                keyboardType: TextInputType.multiline,
                                textAlignVertical: TextAlignVertical.top,
                                textAlign: _alignment == _JsonAlignment.center
                                    ? TextAlign.center
                                    : TextAlign.start,
                                autocorrect: false,
                                enableSuggestions: false,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: _editorFontSize,
                                  height: 1.45,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.all(14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: 'Le JSON du layout apparaîtra ici',
                                  hintStyle: const TextStyle(color: Colors.white24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                onPressed: _loading || _saving ? null : _saveLayout,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre d'options : vue (taille, wrap, numéros) + alignement.
class _EditorOptionsBar extends StatelessWidget {
  final _JsonTextSize textSize;
  final ValueChanged<_JsonTextSize> onTextSizeChanged;
  final bool wrapLines;
  final ValueChanged<bool> onWrapLinesChanged;
  final _JsonAlignment alignment;
  final ValueChanged<_JsonAlignment> onAlignmentChanged;
  final bool showLineNumbers;
  final ValueChanged<bool> onShowLineNumbersChanged;

  const _EditorOptionsBar({
    required this.textSize,
    required this.onTextSizeChanged,
    required this.wrapLines,
    required this.onWrapLinesChanged,
    required this.alignment,
    required this.onAlignmentChanged,
    required this.showLineNumbers,
    required this.onShowLineNumbersChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _OptionLabel('Vue'),
            const SizedBox(width: 6),
            for (final size in _JsonTextSize.values)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: _OptionChip(
                  label: switch (size) {
                    _JsonTextSize.small => 'S',
                    _JsonTextSize.medium => 'M',
                    _JsonTextSize.large => 'L',
                  },
                  selected: textSize == size,
                  accent: accent,
                  onTap: () => onTextSizeChanged(size),
                ),
              ),
            _VerticalDivider(),
            _OptionToggle(
              icon: Icons.subject_rounded,
              label: 'Retour à la ligne',
              selected: wrapLines,
              accent: accent,
              onTap: () => onWrapLinesChanged(!wrapLines),
            ),
            _VerticalDivider(),
            _OptionToggle(
              icon: Icons.format_list_numbered_rounded,
              label: 'Numéros',
              selected: showLineNumbers,
              accent: accent,
              onTap: () => onShowLineNumbersChanged(!showLineNumbers),
            ),
            _VerticalDivider(),
            _OptionLabel('Alignement'),
            const SizedBox(width: 6),
            _OptionToggle(
              icon: Icons.subject_rounded,
              label: 'Gauche',
              selected: alignment == _JsonAlignment.left,
              accent: accent,
              onTap: () => onAlignmentChanged(_JsonAlignment.left),
            ),
            const SizedBox(width: 5),
            _OptionToggle(
              icon: Icons.subject_rounded,
              label: 'Centre',
              selected: alignment == _JsonAlignment.center,
              accent: accent,
              onTap: () => onAlignmentChanged(_JsonAlignment.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionLabel extends StatelessWidget {
  const _OptionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OptionToggle extends StatelessWidget {
  const _OptionToggle({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: .16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent.withValues(alpha: .55) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? accent : Colors.white54),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: Colors.white.withValues(alpha: .1),
    );
  }
}

/// Gouttière de numéros de ligne synchronisée avec le défilement du champ.
class _LineNumbersGutter extends StatelessWidget {
  const _LineNumbersGutter({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final lineCount = controller.text.split('\n').length;
    return Container(
      width: 42,
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: .07)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 1; i <= lineCount; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Text(
                  '$i',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: .28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
