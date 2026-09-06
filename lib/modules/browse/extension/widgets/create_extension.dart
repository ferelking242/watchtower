import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class CreateExtension extends ConsumerStatefulWidget {
  const CreateExtension({super.key});

  @override
  ConsumerState<CreateExtension> createState() => _CreateExtensionState();
}

class _CreateExtensionState extends ConsumerState<CreateExtension> {
  String _name = "";
  String _lang = "";
  String _baseUrl = "";
  String _apiUrl = "";
  String _iconUrl = "";
  String _notes = "";
  String _iconPreviewUrl = "";
  Timer? _iconDebounce;
  int _sourceTypeIndex = 0;
  int _itemTypeIndex = 0;
  SourceCodeLanguage _sourceCodeLanguage = SourceCodeLanguage.dart;

  final List<String> _sourceTypes = ["single", "multi", "torrent"];
  final List<String> _itemTypes = ["Manga", "Anime", "Novel"];

  static const _langOptions = [
    (lang: SourceCodeLanguage.dart,       label: 'Dart',          subtitle: 'Native · Recommandé', emoji: '🎯', color: Color(0xFF54C5F8)),
    (lang: SourceCodeLanguage.javascript, label: 'JavaScript',    subtitle: 'JS universel',         emoji: '𝐉𝐒', color: Color(0xFFF7DF1E)),
  ];

  static const _commonFlags = {
    'en': '🇬🇧', 'fr': '🇫🇷', 'ja': '🇯🇵', 'zh': '🇨🇳', 'ko': '🇰🇷',
    'es': '🇪🇸', 'pt': '🇵🇹', 'de': '🇩🇪', 'it': '🇮🇹', 'ru': '🇷🇺',
    'ar': '🇸🇦', 'tr': '🇹🇷', 'pl': '🇵🇱', 'nl': '🇳🇱', 'id': '🇮🇩',
    'th': '🇹🇭', 'vi': '🇻🇳', 'all': '🌐',
  };

  bool get _canProceed =>
      _name.isNotEmpty && _lang.isNotEmpty && _baseUrl.isNotEmpty && _iconUrl.isNotEmpty;

  Source? _buildSource() {
    try {
      final id = _sourceCodeLanguage == SourceCodeLanguage.dart
          ? 'watchtower-$_lang.$_name'.hashCode
          : 'watchtower-js-$_lang.$_name'.hashCode;
      final existing = isar.sources.getSync(id);
      if (existing != null) return existing;
      final source = Source(
        id: id,
        name: _name,
        lang: _lang,
        baseUrl: _baseUrl,
        apiUrl: _apiUrl,
        iconUrl: _iconUrl,
        typeSource: _sourceTypes[_sourceTypeIndex],
        itemType: ItemType.values.elementAt(_itemTypeIndex),
        isAdded: true,
        isActive: true,
        version: "0.0.1",
        isNsfw: false,
        notes: _notes,
      )..sourceCodeLanguage = _sourceCodeLanguage;
      final withCode = source
        ..isLocal = true
        ..sourceCode = _sourceCodeLanguage == SourceCodeLanguage.dart
            ? _dartTemplate
            : _jsSample(source);
      isar.writeTxnSync(() {
        isar.sources.putSync(
          withCode..updatedAt = DateTime.now().millisecondsSinceEpoch,
        );
      });
      return withCode;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _iconDebounce?.cancel();
    super.dispose();
  }

  void _onIconUrlChanged(String v) {
    setState(() => _iconUrl = v);
    _iconDebounce?.cancel();
    if (v.isEmpty) {
      setState(() => _iconPreviewUrl = '');
      return;
    }
    _iconDebounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _iconPreviewUrl = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.extension_rounded, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 10),
            const Text('Créer une extension'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(cs: cs),
              const SizedBox(height: 16),

              _SectionHeader(label: 'LANGAGE', icon: Icons.code_rounded),
              const SizedBox(height: 8),
              _LanguagePicker(
                selected: _sourceCodeLanguage,
                options: _langOptions,
                onChanged: (l) => setState(() => _sourceCodeLanguage = l),
              ),
              const SizedBox(height: 20),

              _SectionHeader(label: 'INFORMATIONS', icon: Icons.info_outline_rounded),
              const SizedBox(height: 8),
              _FieldRow(label: 'Nom', hint: 'ex: myAnime', onChanged: (v) => setState(() => _name = v)),
              const SizedBox(height: 10),

              _LangField(
                flags: _commonFlags,
                onChanged: (v) => setState(() => _lang = v),
              ),
              const SizedBox(height: 10),

              _FieldRow(label: 'URL de base', hint: 'https://exemple.com', onChanged: (v) => setState(() => _baseUrl = v)),
              const SizedBox(height: 10),
              _FieldRow(label: 'API URL (optionnel)', hint: 'https://api.exemple.com', onChanged: (v) => setState(() => _apiUrl = v)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FieldRow(
                      label: 'URL icône',
                      hint: 'https://exemple.com/icon.png',
                      onChanged: _onIconUrlChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Live preview with 800ms debounce
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _iconPreviewUrl.isNotEmpty
                        ? ClipRRect(
                            key: ValueKey(_iconPreviewUrl),
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _iconPreviewUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.broken_image_rounded,
                                    size: 20, color: cs.error),
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('empty'),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: cs.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: Icon(Icons.image_outlined,
                                size: 20, color: cs.onSurfaceVariant),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FieldRow(label: 'Notes', hint: 'ex: nécessite une connexion', onChanged: (v) => setState(() => _notes = v)),
              const SizedBox(height: 20),

              _SectionHeader(label: 'TYPE', icon: Icons.category_outlined),
              const SizedBox(height: 8),
              _DropdownRow(
                label: 'Source',
                items: _sourceTypes,
                value: _sourceTypeIndex,
                onChanged: (v) => setState(() => _sourceTypeIndex = v),
                cs: cs,
              ),
              const SizedBox(height: 10),
              _DropdownRow(
                label: 'Contenu',
                items: _itemTypes,
                value: _itemTypeIndex,
                onChanged: (v) => setState(() => _itemTypeIndex = v),
                cs: cs,
                icons: [Icons.auto_stories_outlined, Icons.live_tv_outlined, Icons.text_snippet_outlined],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed ? cs.primary : cs.surfaceContainerHighest,
                    foregroundColor: _canProceed ? cs.onPrimary : cs.onSurfaceVariant,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: _canProceed ? 3 : 0,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text(
                    'Suivant — Éditeur de code',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: _canProceed
                      ? () {
                          final src = _buildSource();
                          if (src != null) {
                            context.pop();
                            context.push('/codeEditor', extra: src.id);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Ce nom d\'extension existe déjà.'),
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ),
              if (!_canProceed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Remplis le nom, la langue, l\'URL de base et l\'icône pour continuer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets helpers ───────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final ColorScheme cs;
  const _InfoBanner({required this.cs});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withValues(alpha: 0.14), cs.tertiary.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Configure les métadonnées, puis passe à l\'éditeur de code pour implémenter la logique.',
              style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.85), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final SourceCodeLanguage selected;
  final List<({SourceCodeLanguage lang, String label, String subtitle, String emoji, Color color})> options;
  final ValueChanged<SourceCodeLanguage> onChanged;

  const _LanguagePicker({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: options.map((opt) {
        final active = selected == opt.lang;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt.lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: active
                    ? opt.color.withValues(alpha: 0.18)
                    : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? opt.color : cs.outline.withValues(alpha: 0.15),
                  width: active ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    opt.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? opt.color : cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    opt.subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: (active ? opt.color : cs.onSurfaceVariant).withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? opt.color : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LangField extends StatefulWidget {
  final Map<String, String> flags;
  final ValueChanged<String> onChanged;
  const _LangField({required this.flags, required this.onChanged});
  @override
  State<_LangField> createState() => _LangFieldState();
}

class _LangFieldState extends State<_LangField> {
  String? _selected;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                onChanged: (v) {
                  setState(() => _selected = v.isEmpty ? null : v.toLowerCase());
                  widget.onChanged(v.toLowerCase());
                },
                decoration: InputDecoration(
                  labelText: 'Langue (code ISO)',
                  hintText: 'ex: fr, en, ja',
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _selected != null && widget.flags.containsKey(_selected)
                          ? widget.flags[_selected]!
                          : '🏳️',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: widget.flags.entries.map((e) {
              final active = _selected == e.key;
              return GestureDetector(
                onTap: () {
                  _controller.text = e.key;
                  setState(() => _selected = e.key);
                  widget.onChanged(e.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? cs.primary : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? cs.primary : cs.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.value, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        e.key.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active ? cs.onPrimary : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  const _FieldRow({required this.label, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        labelStyle: TextStyle(fontSize: 12, color: cs.primary.withValues(alpha: 0.8)),
        hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final List<String> items;
  final int value;
  final ValueChanged<int> onChanged;
  final ColorScheme cs;
  final List<IconData>? icons;

  const _DropdownRow({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.cs,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, color: cs.primary),
          hint: Text(label, style: const TextStyle(fontSize: 13)),
          items: items.asMap().entries.map((e) {
            return DropdownMenuItem<int>(
              value: e.key,
              child: Row(
                children: [
                  if (icons != null && e.key < icons!.length) ...[
                    Icon(icons![e.key], size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                  ],
                  Text('$label — ${e.value}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}

// ─── Templates ────────────────────────────────────────────────────────────────

const _dartTemplate = r'''
import 'package:watchtower/bridge_lib.dart';
import 'dart:convert';

class TestSource extends MProvider {
  TestSource({required this.source});

  MSource source;

  final Client client = Client();

  @override
  bool get supportsLatest => true;

  @override
  Map<String, String> get headers => {};
  
  @override
  Future<MPages> getPopular(int page) async {
    // TODO: implement
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    // TODO: implement
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    // TODO: implement
  }

  @override
  Future<MManga> getDetail(String url) async {
    // TODO: implement
  }
  
  @override
  Future<String> getHtmlContent(String name, String url) async {
    // TODO: implement
  }
  
  @override
  Future<String> cleanHtmlContent(String html) async {
    // TODO: implement
  }
  
  @override
  Future<List<MVideo>> getVideoList(String url) async {
    // TODO: implement
  }

  @override
  Future<List<String>> getPageList(String url) async{
    // TODO: implement
  }

  @override
  List<dynamic> getFilterList() {
    // TODO: implement
  }

  @override
  List<dynamic> getSourcePreferences() {
    // TODO: implement
  }
}

TestSource main(MSource source) {
  return TestSource(source:source);
}''';

String _jsSample(Source source) => '''
const watchtowerSources = [{
    "name": "${source.name}",
    "lang": "${source.lang}",
    "baseUrl": "${source.baseUrl}",
    "apiUrl": "${source.apiUrl}",
    "iconUrl": "${source.iconUrl}",
    "typeSource": "${source.typeSource}",
    "itemType": ${source.itemType.index},
    "version": "${source.version}",
    "pkgPath": "",
    "notes": ""
}];

class DefaultExtension extends MProvider {
    getHeaders(url) {
        throw new Error("getHeaders not implemented");
    }
    async getPopular(page) {
        throw new Error("getPopular not implemented");
    }
    get supportsLatest() {
        throw new Error("supportsLatest not implemented");
    }
    async getLatestUpdates(page) {
        throw new Error("getLatestUpdates not implemented");
    }
    async search(query, page, filters) {
        throw new Error("search not implemented");
    }
    async getDetail(url) {
        throw new Error("getDetail not implemented");
    }
    async getHtmlContent(name, url) {
        throw new Error("getHtmlContent not implemented");
    }
    async cleanHtmlContent(html) {
        throw new Error("cleanHtmlContent not implemented");
    }
    async getVideoList(url) {
        throw new Error("getVideoList not implemented");
    }
    async getPageList(url) {
        throw new Error("getPageList not implemented");
    }
    getFilterList() {
        throw new Error("getFilterList not implemented");
    }
    getSourcePreferences() {
        throw new Error("getSourcePreferences not implemented");
    }
}
''';
