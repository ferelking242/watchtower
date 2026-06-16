import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:watchtower/modules/plugins/plugins_screen.dart'
      show installedPluginsProvider, PluginEntry;

  // ─────────────────────────────────────────────────────────────────────────────
  // ManifestUiRenderer — Native Flutter renderer pour les extensions Watchtower
  //
  // Lit le fichier ui/schema.json d'un plugin (défini dans son manifest.json)
  // et construit une UI native Flutter : champs de saisie, sélecteurs, toggles,
  // boutons d'action et zone de résultat — sans WebView.
  //
  // Schéma JSON (ui/schema.json) :
  // {
  //   "version": 1,
  //   "title": "TikTok Downloader",
  //   "subtitle": "Téléchargez des vidéos TikTok",
  //   "inputs": [
  //     { "id": "url",     "type": "url_field",  "label": "URL TikTok", "placeholder": "https://vm.tiktok.com/...", "required": true },
  //     { "id": "quality", "type": "select",     "label": "Qualité",    "options": ["Auto","720p","1080p"],         "default": "Auto" },
  //     { "id": "audio",   "type": "toggle",     "label": "Audio seul", "default": false }
  //   ],
  //   "actions": [
  //     { "id": "download", "label": "Télécharger", "style": "primary", "icon": "download" }
  //   ],
  //   "output": { "type": "log", "label": "Progression" }
  // }
  // ─────────────────────────────────────────────────────────────────────────────

  const Color _bg    = Color(0xFF0F0F0F);
  const Color _card  = Color(0xFF1A1A1A);
  const Color _card2 = Color(0xFF222222);
  const Color _teal  = Color(0xFF00D4AA);
  const Color _grey  = Color(0xFF888888);
  const Color _border = Color(0xFF2A2A2A);

  // ─── Schema models ────────────────────────────────────────────────────────────

  enum _InputType { urlField, textField, select, toggle, unknown }

  class _InputSpec {
    final String id;
    final _InputType type;
    final String label;
    final String placeholder;
    final bool required;
    final List<String> options;
    final dynamic defaultValue;

    const _InputSpec({
      required this.id,
      required this.type,
      required this.label,
      this.placeholder = '',
      this.required = false,
      this.options = const [],
      this.defaultValue,
    });

    factory _InputSpec.fromJson(Map<String, dynamic> j) {
      final typeStr = j['type'] as String? ?? '';
      final type = switch (typeStr) {
        'url_field'  => _InputType.urlField,
        'text_field' => _InputType.textField,
        'select'     => _InputType.select,
        'toggle'     => _InputType.toggle,
        _            => _InputType.unknown,
      };
      return _InputSpec(
        id: j['id'] as String? ?? '',
        type: type,
        label: j['label'] as String? ?? '',
        placeholder: j['placeholder'] as String? ?? '',
        required: j['required'] as bool? ?? false,
        options: (j['options'] as List?)?.cast<String>() ?? [],
        defaultValue: j['default'],
      );
    }
  }

  class _ActionSpec {
    final String id;
    final String label;
    final String style;
    final String icon;

    const _ActionSpec({
      required this.id,
      required this.label,
      this.style = 'primary',
      this.icon = '',
    });

    factory _ActionSpec.fromJson(Map<String, dynamic> j) => _ActionSpec(
      id: j['id'] as String? ?? '',
      label: j['label'] as String? ?? '',
      style: j['style'] as String? ?? 'primary',
      icon: j['icon'] as String? ?? '',
    );
  }

  class _OutputSpec {
    final String type;
    final String label;
    const _OutputSpec({this.type = 'log', this.label = 'Résultat'});
    factory _OutputSpec.fromJson(Map<String, dynamic> j) => _OutputSpec(
      type: j['type'] as String? ?? 'log',
      label: j['label'] as String? ?? 'Résultat',
    );
  }

  class _UiSchema {
    final int version;
    final String title;
    final String subtitle;
    final List<_InputSpec> inputs;
    final List<_ActionSpec> actions;
    final _OutputSpec? output;

    const _UiSchema({
      required this.version,
      required this.title,
      required this.subtitle,
      required this.inputs,
      required this.actions,
      this.output,
    });

    factory _UiSchema.fromJson(Map<String, dynamic> j) => _UiSchema(
      version: j['version'] as int? ?? 1,
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String? ?? '',
      inputs: (j['inputs'] as List? ?? [])
          .map((e) => _InputSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      actions: (j['actions'] as List? ?? [])
          .map((e) => _ActionSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      output: j['output'] != null
          ? _OutputSpec.fromJson(j['output'] as Map<String, dynamic>)
          : null,
    );
  }

  // ─── Main widget ──────────────────────────────────────────────────────────────

  class ManifestUiRenderer extends StatefulWidget {
    /// Path to the plugin's installed directory (contains ui/schema.json).
    final String pluginDir;
    final String pluginId;
    final String pluginName;
    final String pluginIconUrl;
    final void Function(String actionId, Map<String, dynamic> values) onAction;

    const ManifestUiRenderer({
      required this.pluginDir,
      required this.pluginId,
      required this.pluginName,
      required this.pluginIconUrl,
      required this.onAction,
      super.key,
    });

    @override
    State<ManifestUiRenderer> createState() => _ManifestUiRendererState();
  }

  class _ManifestUiRendererState extends State<ManifestUiRenderer> {
    _UiSchema? _schema;
    bool _loading = true;
    String? _error;
    bool _running = false;

    // Field state
    final Map<String, TextEditingController> _textCtrls = {};
    final Map<String, String> _selectValues = {};
    final Map<String, bool> _toggleValues = {};

    // Output
    final List<String> _logLines = [];
    final ScrollController _logScroll = ScrollController();

    @override
    void initState() {
      super.initState();
      _loadSchema();
    }

    @override
    void dispose() {
      for (final c in _textCtrls.values) c.dispose();
      _logScroll.dispose();
      super.dispose();
    }

    Future<void> _loadSchema() async {
      setState(() { _loading = true; _error = null; });
      try {
        final schemaFile = File('${widget.pluginDir}/ui/schema.json');
        if (!await schemaFile.exists()) {
          setState(() { _loading = false; _error = 'Pas de UI schema trouvé (ui/schema.json manquant).'; });
          return;
        }
        final raw = await schemaFile.readAsString();
        final schema = _UiSchema.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        // Init field controllers
        for (final inp in schema.inputs) {
          if (inp.type == _InputType.urlField || inp.type == _InputType.textField) {
            _textCtrls[inp.id] = TextEditingController(
              text: inp.defaultValue?.toString() ?? '',
            );
          } else if (inp.type == _InputType.select) {
            _selectValues[inp.id] = inp.defaultValue?.toString() ??
                (inp.options.isNotEmpty ? inp.options.first : '');
          } else if (inp.type == _InputType.toggle) {
            _toggleValues[inp.id] = inp.defaultValue as bool? ?? false;
          }
        }
        setState(() { _schema = schema; _loading = false; });
      } catch (e) {
        setState(() { _loading = false; _error = 'Erreur de lecture du schema : $e'; });
      }
    }

    Map<String, dynamic> _collectValues() {
      final values = <String, dynamic>{};
      for (final e in _textCtrls.entries) values[e.key] = e.value.text.trim();
      values.addAll(_selectValues);
      values.addAll(_toggleValues);
      return values;
    }

    bool _validate() {
      if (_schema == null) return false;
      for (final inp in _schema!.inputs) {
        if (!inp.required) continue;
        if ((inp.type == _InputType.urlField || inp.type == _InputType.textField) &&
            (_textCtrls[inp.id]?.text.trim().isEmpty ?? true)) {
          _addLog('⚠ Champ requis vide : ${inp.label}');
          return false;
        }
      }
      return true;
    }

    void _addLog(String line) {
      setState(() => _logLines.add(line));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScroll.hasClients) {
          _logScroll.animateTo(
            _logScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    Future<void> _handleAction(_ActionSpec action) async {
      if (_running || !_validate()) return;
      HapticFeedback.mediumImpact();
      setState(() { _running = true; _logLines.clear(); });
      _addLog('▶ ${action.label} démarré…');
      try {
        widget.onAction(action.id, _collectValues());
      } finally {
        if (mounted) setState(() => _running = false);
      }
    }

    void addOutputLine(String line) => _addLog(line);

    @override
    Widget build(BuildContext context) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator(color: _teal));
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: _grey), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadSchema, child: const Text('Réessayer', style: TextStyle(color: _teal))),
            ]),
          ),
        );
      }
      final schema = _schema!;
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            schema.title.isNotEmpty ? schema.title : widget.pluginName,
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (schema.subtitle.isNotEmpty) ...[
              Text(schema.subtitle,
                style: const TextStyle(fontSize: 13, color: _grey, height: 1.45)),
              const SizedBox(height: 16),
            ],
            // ── Inputs ────────────────────────────────────────────────────
            ...schema.inputs.map((inp) => _buildInput(inp)),
            const SizedBox(height: 20),
            // ── Actions ───────────────────────────────────────────────────
            ...schema.actions.map((act) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildActionButton(act),
            )),
            // ── Output ────────────────────────────────────────────────────
            if (schema.output != null && _logLines.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildOutputZone(schema.output!),
            ],
          ],
        ),
      );
    }

    Widget _buildInput(_InputSpec inp) {
      switch (inp.type) {
        case _InputType.urlField:
        case _InputType.textField:
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(label: inp.label, required: inp.required),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrls[inp.id],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: inp.placeholder.isNotEmpty ? inp.placeholder : inp.label,
                          hintStyle: const TextStyle(color: _grey, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        ),
                        keyboardType: inp.type == _InputType.urlField
                            ? TextInputType.url
                            : TextInputType.text,
                      ),
                    ),
                    if (inp.type == _InputType.urlField)
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18, color: _grey),
                        onPressed: () async {
                          final clip = await Clipboard.getData(Clipboard.kTextPlain);
                          if (clip?.text != null) {
                            _textCtrls[inp.id]?.text = clip!.text!;
                          }
                        },
                        tooltip: 'Coller',
                      ),
                  ]),
                ),
              ],
            ),
          );

        case _InputType.select:
          final current = _selectValues[inp.id] ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(label: inp.label, required: inp.required),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: inp.options.contains(current) ? current : (inp.options.isNotEmpty ? inp.options.first : null),
                      items: inp.options
                          .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(color: Colors.white, fontSize: 14))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectValues[inp.id] = v);
                      },
                      dropdownColor: _card2,
                      style: const TextStyle(color: Colors.white),
                      isExpanded: true,
                      icon: const Icon(Icons.expand_more_rounded, color: _grey),
                    ),
                  ),
                ),
              ],
            ),
          );

        case _InputType.toggle:
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: SwitchListTile(
                value: _toggleValues[inp.id] ?? false,
                onChanged: (v) => setState(() => _toggleValues[inp.id] = v),
                title: Text(inp.label, style: const TextStyle(color: Colors.white, fontSize: 14)),
                activeColor: _teal,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );

        case _InputType.unknown:
          return const SizedBox.shrink();
      }
    }

    Widget _buildActionButton(_ActionSpec action) {
      final isPrimary = action.style == 'primary';
      final icon = _resolveIcon(action.icon);
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _running ? null : () => _handleAction(action),
          style: FilledButton.styleFrom(
            backgroundColor: isPrimary ? _teal : _card2,
            foregroundColor: isPrimary ? Colors.black : Colors.white,
            disabledBackgroundColor: _card2.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          icon: _running && isPrimary
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
              : Icon(icon, size: 18),
          label: Text(_running && isPrimary ? 'En cours…' : action.label),
        ),
      );
    }

    Widget _buildOutputZone(_OutputSpec spec) {
      return Container(
        decoration: BoxDecoration(
          color: _card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(children: [
                const Icon(Icons.terminal_rounded, size: 13, color: _teal),
                const SizedBox(width: 6),
                Text(spec.label.toUpperCase(),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _grey, letterSpacing: 0.8)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _logLines.clear()),
                  child: const Icon(Icons.clear_all_rounded, size: 16, color: _grey),
                ),
              ]),
            ),
            const Divider(color: _border, height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                controller: _logScroll,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: _logLines.length,
                itemBuilder: (_, i) => Text(
                  _logLines[i],
                  style: const TextStyle(
                    fontSize: 12, color: Color(0xFFCCCCCC),
                    fontFamily: 'monospace', height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    IconData _resolveIcon(String name) {
      return switch (name) {
        'download'    => Icons.download_rounded,
        'play'        => Icons.play_arrow_rounded,
        'search'      => Icons.search_rounded,
        'send'        => Icons.send_rounded,
        'check'       => Icons.check_rounded,
        'refresh'     => Icons.refresh_rounded,
        _             => Icons.bolt_rounded,
      };
    }
  }

  // ─── Helper widgets ───────────────────────────────────────────────────────────

  class _FieldLabel extends StatelessWidget {
    final String label;
    final bool required;
    const _FieldLabel({required this.label, this.required = false});

    @override
    Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grey)),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
  