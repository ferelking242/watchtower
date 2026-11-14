import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:watchtower/models/gallery_component_palette.dart';
import 'package:watchtower/models/layout_component_registry.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Fiche détail d'un composant de la galerie.
///
/// Ouverte depuis le bouton « i » de chaque carte, à côté du bouton copier.
/// Elle rappelle l'identifiant JSON, tous les noms et surnoms utilisables, la
/// liste complète des paramètres acceptés (type, défaut, exemple, alias) et un
/// exemple de section prêt à coller dans `layout.json`.
/// ─────────────────────────────────────────────────────────────────────────

/// Ouvre la fiche détail du composant décrit par [data].
Future<void> showComponentDetail(
  BuildContext context,
  GalleryComponentDetailData data,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF12171E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => ComponentDetailSheet(data: data),
  );
}

/// Données neutres affichées par [ComponentDetailSheet], pour que la fiche ne
/// dépende pas des types privés de l'écran de galerie.
class GalleryComponentDetailData {
  const GalleryComponentDetailData({
    required this.title,
    required this.className,
    required this.path,
    required this.usage,
    required this.icon,
    this.componentId,
  });

  final String title;
  final String className;
  final String path;
  final String usage;
  final IconData icon;

  /// Identifiant `component` du layout JSON, `null` pour un exemple non
  /// sélectionnable.
  final String? componentId;
}

class ComponentDetailSheet extends StatelessWidget {
  const ComponentDetailSheet({required this.data, super.key});

  final GalleryComponentDetailData data;

  @override
  Widget build(BuildContext context) {
    final id = data.componentId;
    final definition = id == null ? null : LayoutComponentRegistry.resolve(id);
    final family = definition?.galleryFamily;
    final parameters = family == null
        ? const <GalleryComponentParameter>[]
        : GalleryComponentPalette.forFamily(family);
    final aliases = definition?.aliases ?? const <String>[];
    final grouped = <GalleryParameterGroup, List<GalleryComponentParameter>>{};
    for (final parameter in parameters) {
      grouped.putIfAbsent(parameter.group, () => []).add(parameter);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  data.icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.usage,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DetailSection(
            title: 'Identifiant',
            children: [
              _DetailKeyValue(
                label: 'component',
                value: id ?? '— (démonstration, non sélectionnable)',
                copyable: id != null,
              ),
              _DetailKeyValue(label: 'classe Dart', value: data.className),
              _DetailKeyValue(label: 'source', value: data.path),
              if (definition != null)
                _DetailKeyValue(label: 'catégorie', value: definition.category),
            ],
          ),
          if (id != null && aliases.isNotEmpty)
            _DetailSection(
              title: 'Noms et surnoms utilisables',
              children: [
                const _DetailParagraph(
                  'Toutes ces valeurs sont acceptées à la place de '
                  '`component` : le rendu est identique. Utile pour garder un '
                  'layout lisible (« ranked-media » plutôt qu\'un id court).',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _DetailChip(label: id, highlight: true),
                    for (final alias in aliases) _DetailChip(label: alias),
                  ],
                ),
              ],
            ),
          _DetailSection(
            title: 'Paramètres',
            children: [
              _DetailParagraph(
                parameters.isEmpty
                    ? 'Ce composant est un exemple de section : il est piloté '
                          'par les données de la source, sans paramètre de '
                          'layout propre.'
                    : 'Chaque paramètre se place dans l\'objet `params` de la '
                          'section. Les valeurs absentes gardent le défaut '
                          'indiqué.',
              ),
              for (final group in GalleryParameterGroup.values)
                if (grouped[group] != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    group.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final parameter in grouped[group]!) ...[
                    _ParameterTile(parameter: parameter),
                    const SizedBox(height: 8),
                  ],
                ],
            ],
          ),
          if (id != null) ...[
            const SizedBox(height: 6),
            _DetailSection(
              title: 'Exemple de section',
              children: [
                const _DetailParagraph(
                  'Section complète telle qu\'elle peut être écrite dans '
                  'layout.json. Adapte les valeurs à ta source.',
                ),
                const SizedBox(height: 10),
                _DetailCode(_exampleSectionJson(id, data.title, parameters)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Construit un exemple de section JSON prêt à coller, en ne gardant que des
/// paramètres démonstratifs (jamais toute la palette).
String _exampleSectionJson(
  String id,
  String title,
  List<GalleryComponentParameter> parameters,
) {
  const keys = {'items', 'layout', 'columns', 'spacing', 'color', 'animation'};
  final params = <String, String>{};
  for (final parameter in parameters) {
    if (!keys.contains(parameter.key)) continue;
    params[parameter.key] = _exampleValue(parameter);
  }
  final buffer = StringBuffer()
    ..writeln('{')
    ..writeln('  "id": "${id}_section",')
    ..writeln('  "component": "$id",')
    ..writeln('  "title": "$title",')
    ..writeln('  "params": {');
  final entries = params.entries.toList();
  for (var i = 0; i < entries.length; i++) {
    final comma = i == entries.length - 1 ? '' : ',';
    buffer.writeln('    "${entries[i].key}": ${entries[i].value}$comma');
  }
  buffer
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString().trimRight();
}

String _exampleValue(GalleryComponentParameter parameter) {
  final example = parameter.example;
  return switch (parameter.kind) {
    GalleryParameterKind.number => example ?? '6',
    GalleryParameterKind.boolean => 'true',
    GalleryParameterKind.selection =>
      '"${parameter.options.isEmpty ? 'row' : parameter.options.first}"',
    GalleryParameterKind.text => '"${example ?? 'Valeur'}"',
  };
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailKeyValue extends StatelessWidget {
  const _DetailKeyValue({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontFamily: 'monospace',
                height: 1.3,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copier',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: value));
                } catch (_) {
                  return;
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('$value copié'),
                      duration: const Duration(milliseconds: 1000),
                    ),
                  );
              },
              icon: const Icon(
                Icons.copy_rounded,
                size: 15,
                color: Colors.white38,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailParagraph extends StatelessWidget {
  const _DetailParagraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
  );
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? accent.withValues(alpha: .16)
            : Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? accent.withValues(alpha: .4)
              : Colors.white.withValues(alpha: .1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlight ? Colors.white : Colors.white70,
          fontSize: 11.5,
          fontFamily: 'monospace',
          fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailCode extends StatelessWidget {
  const _DetailCode(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              code,
              style: const TextStyle(
                color: Color(0xFFB6D7A8),
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.45,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copier l\'exemple',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: code));
              } catch (_) {
                return;
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Exemple copié'),
                    duration: Duration(milliseconds: 1000),
                  ),
                );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de paramètre : clé, type, défaut, exemple, alias et description.
class _ParameterTile extends StatelessWidget {
  const _ParameterTile({required this.parameter});

  final GalleryComponentParameter parameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  parameter.key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  parameter.typeName,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            parameter.label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (parameter.description != null) ...[
            const SizedBox(height: 5),
            Text(
              parameter.description!,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DetailChip(label: 'défaut: ${parameter.effectiveDefault}'),
              if (parameter.example != null)
                _DetailChip(label: 'ex: ${parameter.example}'),
              if (parameter.options.isNotEmpty)
                _DetailChip(label: parameter.options.join(' | ')),
              for (final alias in parameter.aliases)
                _DetailChip(label: 'alias: $alias'),
            ],
          ),
        ],
      ),
    );
  }
}
