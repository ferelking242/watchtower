import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/providers/custom_sections_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/language.dart';

/// Opens the "Mes sections" manager: create a named section, rename or delete
/// one, and add/remove the installed extensions that belong to it.
///
/// A section is a user-defined shelf — "Hentai", "Lecteurs FR", … — so an
/// extension can be grouped by intent rather than only by language.
Future<void> showCustomSectionsManager(
  BuildContext context,
  ItemType itemType,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomSectionsSheet(itemType: itemType),
  );
}

/// Adds/removes a single [source] from the user's sections.
Future<void> showAddToSectionSheet(BuildContext context, Source source) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToSectionSheet(source: source),
  );
}

List<Source> _installedSources(ItemType itemType) {
  try {
    return isar.sources
        .where()
        .findAllSync()
        .where(
          (s) =>
              s.itemType == itemType &&
              s.isAdded == true &&
              !(s.name == 'local' && (s.lang ?? '').isEmpty),
        )
        .toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
  } catch (_) {
    return const [];
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  const _SheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Manager ───────────────────────────────────────────────────────────────────

class _CustomSectionsSheet extends ConsumerStatefulWidget {
  final ItemType itemType;
  const _CustomSectionsSheet({required this.itemType});

  @override
  ConsumerState<_CustomSectionsSheet> createState() =>
      _CustomSectionsSheetState();
}

class _CustomSectionsSheetState extends ConsumerState<_CustomSectionsSheet> {
  CustomSection? _open;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final sections = ref.watch(customSectionsProvider);
    final cs = Theme.of(context).colorScheme;
    final open = _open == null
        ? null
        : sections.where((s) => s.id == _open!.id).firstOrNull;

    return _SheetShell(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
              child: Row(
                children: [
                  if (open != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Broken.arrow_left_2, size: 20),
                      onPressed: () => setState(() => _open = null),
                    )
                  else
                    Icon(Broken.folder_2, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      open?.name ?? l10n.browse_custom_sections,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (open == null)
                    TextButton.icon(
                      onPressed: () => _promptCreate(context),
                      icon: const Icon(Broken.add_square, size: 18),
                      label: Text(l10n.create),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(Broken.more_2, size: 20),
                      onSelected: (value) {
                        if (value == 'rename') _promptRename(context, open);
                        if (value == 'delete') _confirmDelete(context, open);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(l10n.browse_section_rename_short),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: open == null
                  ? _buildList(sections, cs)
                  : _buildDetail(open, cs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<CustomSection> sections, ColorScheme cs) {
    final l10n = l10nLocalizations(context)!;
    if (sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Icon(Broken.folder_open, size: 42, color: cs.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              l10n.browse_section_empty_title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.browse_section_empty_body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        for (final section in sections)
          ListTile(
            leading: const Icon(Broken.folder_2),
            title: Text(section.name),
            subtitle:
                Text(l10n.browse_section_extension_count(section.sourceIds.length)),
            trailing: const Icon(Broken.arrow_right_2, size: 16),
            onTap: () => setState(() => _open = section),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDetail(CustomSection section, ColorScheme cs) {
    final l10n = l10nLocalizations(context)!;
    final sources = _installedSources(widget.itemType);
    final members = sources
        .where((s) => s.id != null && section.sourceIds.contains(s.id))
        .toList();

    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: OutlinedButton.icon(
            onPressed: () => _openPicker(section, sources),
            icon: const Icon(Broken.add_square, size: 18),
            label: Text(l10n.browse_section_add_extensions),
          ),
        ),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Text(
              l10n.browse_section_detail_empty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          )
        else
          for (final source in members)
            ListTile(
              dense: true,
              leading: const Icon(Broken.element_3, size: 18),
              title: Text(source.name ?? ''),
              subtitle: Text(
                '${langFlagEmoji((source.lang ?? '').toLowerCase())} '
                '${completeLanguageName((source.lang ?? '').toLowerCase())}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                tooltip: l10n.browse_remove_tooltip,
                icon: const Icon(Broken.trash, size: 17),
                onPressed: source.id == null
                    ? null
                    : () => ref
                        .read(customSectionsProvider.notifier)
                        .toggleSource(section.id, source.id!),
              ),
            ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _openPicker(CustomSection section, List<Source> sources) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SectionSourcePicker(sectionId: section.id, sources: sources),
    );
    if (mounted) setState(() {});
  }

  Future<void> _promptCreate(BuildContext context) async {
    final l10n = l10nLocalizations(context)!;
    final name = await _promptName(context, title: l10n.browse_section_new, initial: '');
    if (name == null) return;
    ref.read(customSectionsProvider.notifier).create(name);
  }

  Future<void> _promptRename(BuildContext context, CustomSection section) async {
    final l10n = l10nLocalizations(context)!;
    final name = await _promptName(
      context,
      title: l10n.browse_section_rename,
      initial: section.name,
    );
    if (name == null) return;
    ref.read(customSectionsProvider.notifier).rename(section.id, name);
    if (mounted) setState(() => _open = null);
  }

  void _confirmDelete(BuildContext context, CustomSection section) {
    final l10n = l10nLocalizations(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.browse_section_delete_title(section.name)),
        content: Text(l10n.browse_section_delete_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(customSectionsProvider.notifier).remove(section.id);
              setState(() => _open = null);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  required String initial,
}) {
  final l10n = l10nLocalizations(context)!;
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l10n.browse_section_name_hint),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(l10n.browse_validate),
        ),
      ],
    ),
  );
}

// ── Picker used inside a section ──────────────────────────────────────────────

class _SectionSourcePicker extends ConsumerWidget {
  final String sectionId;
  final List<Source> sources;
  const _SectionSourcePicker({required this.sectionId, required this.sources});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final sections = ref.watch(customSectionsProvider);
    final section = sections.where((s) => s.id == sectionId).firstOrNull;
    final members = section?.sourceIds ?? const <int>{};

    return _SheetShell(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: Row(
                children: [
                  const Icon(Broken.element_3, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    l10n.browse_section_picker_title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (sources.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.browse_section_no_extensions,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final source in sources)
                    CheckboxListTile(
                      dense: true,
                      value: source.id != null && members.contains(source.id),
                      title: Text(source.name ?? ''),
                      subtitle: Text(
                        completeLanguageName((source.lang ?? '').toLowerCase()),
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: source.id == null
                          ? null
                          : (_) => ref
                              .read(customSectionsProvider.notifier)
                              .toggleSource(sectionId, source.id!),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add a source to sections (long-press on a source) ─────────────────────────

class _AddToSectionSheet extends ConsumerWidget {
  final Source source;
  const _AddToSectionSheet({required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final sections = ref.watch(customSectionsProvider);
    final cs = Theme.of(context).colorScheme;

    return _SheetShell(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: Row(
                children: [
                  const Icon(Broken.folder_add, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.browse_section_add_to(source.name ?? ''),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.browse_section_create_first,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else
                    for (final section in sections)
                      CheckboxListTile(
                        dense: true,
                        value: source.id != null &&
                            section.sourceIds.contains(source.id),
                        title: Text(section.name),
                        onChanged: source.id == null
                            ? null
                            : (_) => ref
                                .read(customSectionsProvider.notifier)
                                .toggleSource(section.id, source.id!),
                      ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
