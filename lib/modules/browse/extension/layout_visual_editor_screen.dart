import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart'
    show ExtensionLayoutPreview;
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/services/layout_registry.dart';

part 'layout_visual_editor_widgets.dart';

class LayoutVisualEditorScreen extends StatefulWidget {
  final Source source;

  const LayoutVisualEditorScreen({super.key, required this.source});

  @override
  State<LayoutVisualEditorScreen> createState() =>
      _LayoutVisualEditorScreenState();
}

class _LayoutVisualEditorScreenState extends State<LayoutVisualEditorScreen> {
  Map<String, dynamic>? _layoutJson;
  List<Map<String, dynamic>> _sections = [];
  int? _selectedIndex;
  bool _loading = true;
  bool _saving = false;
  bool _galleryExpanded = false;
  String? _message;
  bool _messageIsError = false;
  String? _sectionIdError;

  Map<String, dynamic>? get _selectedSection {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _sections.length) return null;
    return _sections[index];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadLayout());
  }

  Future<void> _loadLayout() async {
    try {
      var content = await LayoutRegistry.instance.readJson(widget.source);
      if (content == null) {
        final downloaded =
            await LayoutDownloader.instance.download(widget.source);
        if (downloaded) {
          content = await LayoutRegistry.instance.readJson(widget.source);
        }
      }
      if (content == null) {
        throw const FormatException(
          'Aucun layout JSON n’est disponible pour cette extension.',
        );
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('La racine du layout doit être un objet.');
      }
      final home = decoded['home'];
      if (home is! Map<String, dynamic>) {
        throw const FormatException('La section « home » est absente.');
      }
      final rawSections = home['sections'];
      if (rawSections is! List) {
        throw const FormatException('La liste « home.sections » est absente.');
      }
      final sections = rawSections
          .map((section) {
            if (section is! Map<String, dynamic>) {
              throw const FormatException(
                'Chaque section du layout doit être un objet.',
              );
            }
            return Map<String, dynamic>.from(section);
          })
          .toList(growable: true);

      if (!mounted) return;
      setState(() {
        _layoutJson = decoded;
        _sections = sections;
        _selectedIndex = sections.isEmpty ? null : 0;
        _loading = false;
        _message = null;
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

  Future<void> _retryLoadLayout() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    await _loadLayout();
  }

  void _selectSection(int index) {
    if (index < 0 || index >= _sections.length) return;
    setState(() {
      _selectedIndex = index;
      _message = null;
      _sectionIdError = null;
    });
  }

  void _updateSection(String key, Object? value) {
    final section = _selectedSection;
    if (section == null) return;
    setState(() {
      if (value == null) {
        section.remove(key);
      } else {
        section[key] = value;
      }
      _message = null;
    });
  }

  void _reorderSections(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final selectedId = _selectedSection?['id']?.toString();
    setState(() {
      final section = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, section);
      _selectedIndex = selectedId == null
          ? null
          : _sections.indexWhere((item) => item['id']?.toString() == selectedId);
      if (_selectedIndex == -1) _selectedIndex = null;
      _message = null;
    });
  }

  String _nextSectionId() {
    final ids = _sections.map((section) => section['id']?.toString()).toSet();
    if (!ids.contains('popular')) return 'popular';
    if (!ids.contains('latest')) return 'latest';
    var index = 1;
    while (ids.contains('custom_$index')) {
      index++;
    }
    return 'custom_$index';
  }

  void _addSection() {
    final id = _nextSectionId();
    final newSection = <String, dynamic>{
      'id': id,
      'title': switch (id) {
        'popular' => 'Populaires',
        'latest' => 'Dernières sorties',
        _ => 'Nouvelle section',
      },
      'component': 'grid',
    };
    setState(() {
      _sections.add(newSection);
      _selectedIndex = _sections.length - 1;
      _galleryExpanded = true;
      _message = null;
      _sectionIdError = null;
    });
  }

  void _removeSection(int index) {
    setState(() {
      _sections.removeAt(index);
      if (_sections.isEmpty) {
        _selectedIndex = null;
      } else if (_selectedIndex == index) {
        _selectedIndex = index.clamp(0, _sections.length - 1).toInt();
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
      _message = null;
      _sectionIdError = null;
    });
  }

  void _changeSectionId(String value) {
    final section = _selectedSection;
    if (section == null) return;
    final id = value.trim();
    if (id.isEmpty) {
      setState(() => _sectionIdError = 'L’identifiant ne peut pas être vide.');
      return;
    }
    if (_sections.any(
      (candidate) =>
          !identical(candidate, section) && candidate['id']?.toString() == id,
    )) {
      setState(
        () => _sectionIdError = 'Cet identifiant est déjà utilisé.',
      );
      return;
    }
    setState(() {
      section['id'] = id;
      _sectionIdError = null;
      _message = null;
    });
  }

  Future<void> _saveLayout() async {
    final original = _layoutJson;
    if (original == null || _saving || _sectionIdError != null) return;
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final layout = Map<String, dynamic>.from(original);
      final home = Map<String, dynamic>.from(
        layout['home'] as Map<String, dynamic>,
      );
      home['sections'] = _sections
          .map((section) => Map<String, dynamic>.from(section))
          .toList(growable: false);
      layout['home'] = home;
      final formatted = const JsonEncoder.withIndent('  ').convert(layout);
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
        _layoutJson = layout;
        _message = 'Disposition enregistrée sur cet appareil.';
        _messageIsError = false;
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
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      appBar: AppBar(
        title: Text('Éditeur visuel · ${widget.source.name ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer la disposition',
            onPressed: _loading || _saving || _sectionIdError != null
                ? null
                : _saveLayout,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _layoutJson == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 38),
                          const SizedBox(height: 12),
                          Text(
                            _message ?? 'Le layout est indisponible.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _retryLoadLayout,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : wide
                    ? Row(
                        children: [
                          Expanded(child: _buildCanvas()),
                          SizedBox(
                            width: 370,
                            child: _buildInspector(showDivider: true),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 6, child: _buildCanvas()),
                          const Divider(height: 1),
                          Expanded(flex: 5, child: _buildInspector()),
                        ],
                      ),
      ),
    );
  }

  Widget _buildCanvas() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aperçu de l’accueil',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Les cartes sont des exemples. Sélectionne une section, '
                      'puis fais-la glisser pour la déplacer.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Ajouter une section',
                onPressed: _addSection,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _message!,
              style: TextStyle(
                color: _messageIsError ? colors.error : colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: _sections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.dashboard_customize_outlined,
                          size: 42,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        const Text('Aucune section dans cette disposition.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _addSection,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Ajouter une section'),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 28),
                  buildDefaultDragHandles: false,
                  itemCount: _sections.length,
                  onReorder: _reorderSections,
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    final id = section['id']?.toString() ?? 'section_$index';
                    return _SectionCanvasTile(
                      key: ValueKey('layout-section-$id'),
                      source: widget.source,
                      section: section,
                      index: index,
                      selected: _selectedIndex == index,
                      onSelect: () => _selectSection(index),
                      onRemove: () => _removeSection(index),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInspector({bool showDivider = false}) {
    final colors = Theme.of(context).colorScheme;
    final section = _selectedSection;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: showDivider
            ? Border(left: BorderSide(color: colors.outlineVariant))
            : null,
      ),
      child: _sections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Text(
                  'Ajoute une section pour afficher ses options et choisir un composant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Options de la section',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_selectedIndex != null)
                      Text(
                        '${_selectedIndex! + 1} / ${_sections.length}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                  ],
                ),
                if (section == null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Choisis une section dans l’aperçu.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  Text(
                    'Titre',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: ValueKey('section-title-$_selectedIndex'),
                    initialValue: section['title']?.toString() ?? '',
                    decoration: const InputDecoration(
                      hintText: 'Titre affiché',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => _updateSection('title', value),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('section-id-$_selectedIndex'),
                    initialValue: section['id']?.toString() ?? '',
                    decoration: InputDecoration(
                      labelText: 'Identifiant de la liste',
                      helperText: 'Doit correspondre à une liste de l’extension.',
                      errorText: _sectionIdError,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _changeSectionId,
                  ),
                  const SizedBox(height: 18),
                  _buildComponentGallery(section),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberOption(
                          key: ValueKey('columns-${section['id']}'),
                          label: 'Colonnes',
                          value: section['columns'],
                          onChanged: (value) => _updateSection('columns', value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberOption(
                          key: ValueKey('rows-${section['id']}'),
                          label: 'Lignes',
                          value: section['rows'],
                          onChanged: (value) => _updateSection('rows', value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _BooleanOption(
                    title: 'Afficher « Tout voir »',
                    value: section['seeAll'] == true,
                    onChanged: (value) => _updateSection('seeAll', value),
                  ),
                  _BooleanOption(
                    title: 'Charger les pages suivantes',
                    value: section['paginated'] == true,
                    onChanged: (value) => _updateSection('paginated', value),
                  ),
                  _BooleanOption(
                    title: 'Réservé aux comptes connectés',
                    value: section['requiresAuth'] == true,
                    onChanged: (value) => _updateSection('requiresAuth', value),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _saving || _sectionIdError != null ? null : _saveLayout,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Enregistrement…' : 'Enregistrer la disposition',
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildComponentGallery(Map<String, dynamic> section) {
    final colors = Theme.of(context).colorScheme;
    final currentComponent = section['component']?.toString() ?? 'grid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _galleryExpanded = !_galleryExpanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                const Icon(Icons.widgets_outlined, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Galerie des composants',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  _componentLabel(currentComponent),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                      ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _galleryExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _galleryExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: GridView.builder(
            padding: const EdgeInsets.only(top: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _componentOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: .92,
            ),
            itemBuilder: (context, index) {
              final option = _componentOptions[index];
              final selected = option.name == currentComponent;
              return _ComponentGalleryCard(
                source: widget.source,
                option: option,
                selected: selected,
                onTap: () => _updateSection('component', option.name),
              );
            },
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
