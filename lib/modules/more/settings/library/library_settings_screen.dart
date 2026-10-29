import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

/// Library settings, modelled on Mihon's "Bibliothèque" section.
class LibrarySettingsScreen extends ConsumerWidget {
  const LibrarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(libraryUpdateIntervalProvider);
    final wifiOnly = ref.watch(libraryUpdateWifiOnlyProvider);
    final chargingOnly = ref.watch(libraryUpdateChargingOnlyProvider);
    final autoRefresh = ref.watch(libraryAutoRefreshMetadataProvider);
    final checkCover = ref.watch(libraryCheckNewCoverProvider);
    final smartUpdate = ref.watch(librarySmartUpdateProvider);
    final unreadBadge = ref.watch(libraryUnreadBadgeProvider);
    final swipeLeft = ref.watch(librarySwipeLeftProvider);
    final swipeRight = ref.watch(librarySwipeRightProvider);
    final markDuplicate = ref.watch(libraryMarkDuplicateReadProvider);
    final hideMissing = ref.watch(libraryHideMissingChaptersProvider);
    final perCategorySort = ref.watch(libraryPerCategorySortProvider);
    final defaultCategory = ref.watch(defaultCategoryStateProvider);
    final includeCats = ref.watch(libraryUpdateIncludeCategoriesProvider);
    final excludeCats = ref.watch(libraryUpdateExcludeCategoriesProvider);

    final restrictions = <String>[
      if (wifiOnly) 'Wi-Fi',
      if (chargingOnly) 'En charge',
    ];

    return SettingsSubpageScaffold(
      title: 'Bibliothèque',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Catégories ─────────────────────────────────────────────
              _Section(icon: Broken.category, label: 'Catégories'),
              ListTile(
                leading: const Icon(Broken.category_2),
                title: const Text('Catégories'),
                subtitle: const Text(
                  'Créer, renommer et supprimer vos catégories',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/categories', extra: (true, 0)),
              ),
              ListTile(
                leading: const Icon(Broken.edit_2),
                title: const Text('Modifier les catégories'),
                subtitle: const Text(
                  'Réorganiser et affecter les titres',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/categories', extra: (false, 0)),
              ),
              ListTile(
                leading: const Icon(Broken.bookmark),
                title: const Text('Catégorie par défaut'),
                subtitle: Text(
                  defaultCategory,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickDefaultCategory(context, ref, defaultCategory),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.sort),
                value: perCategorySort,
                title: const Text('Rendre les réglages de tri propres à chaque catégorie'),
                onChanged: (v) =>
                    ref.read(libraryPerCategorySortProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Mises à jour ───────────────────────────────────────────
              _Section(icon: Broken.refresh, label: 'Mises à jour'),
              ListTile(
                leading: const Icon(Broken.refresh_circle),
                title: const Text('Mises à jour automatiques'),
                subtitle: Text(
                  kLibraryUpdateIntervalOptions[interval] ?? 'Chaque semaine',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickInterval(context, ref, interval),
              ),
              ListTile(
                leading: const Icon(Broken.battery_charging),
                title: const Text(
                  'Restrictions matérielles pour les mises à jour automatiques',
                ),
                subtitle: Text(
                  'Restrictions: ${restrictions.isEmpty ? 'Aucun(e)' : restrictions.join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickRestrictions(
                  context,
                  ref,
                  wifiOnly: wifiOnly,
                  chargingOnly: chargingOnly,
                ),
              ),
              ListTile(
                leading: const Icon(Broken.category_2),
                title: const Text('Catégories'),
                subtitle: Text(
                  'Inclure: ${_describeCategories(ref, includeCats)}\n'
                  'Exclure: ${_describeCategories(ref, excludeCats)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                isThreeLine: true,
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickCategories(context, ref),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.refresh_square_2),
                value: autoRefresh,
                title: const Text('Actualiser automatiquement les métadonnées'),
                onChanged: (v) =>
                    ref.read(libraryAutoRefreshMetadataProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.image),
                value: checkCover,
                title: const Text(
                  'Vérifier s’il y a une nouvelle couverture ou synopsis lors des mises à jour de la bibliothèque',
                ),
                onChanged: (v) =>
                    ref.read(libraryCheckNewCoverProvider.notifier).set(v),
              ),
              ListTile(
                leading: const Icon(Broken.magicpen),
                title: const Text('Mise à jour intelligente'),
                subtitle: Text(
                  kLibrarySmartUpdateLabels[smartUpdate],
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickSmartUpdate(context, ref, smartUpdate),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.notification_bing),
                value: unreadBadge,
                title: const Text(
                  'Afficher le nombre de chapitres non lus sur l’icône des mises à jour',
                ),
                onChanged: (v) =>
                    ref.read(libraryUnreadBadgeProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Comportement ───────────────────────────────────────────
              _Section(icon: Broken.task, label: 'Comportement'),
              ListTile(
                leading: const Icon(Broken.arrow_left_2),
                title: const Text('Action de glisser à gauche'),
                subtitle: Text(
                  kLibrarySwipeActions[swipeLeft],
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickSwipe(
                  context,
                  ref,
                  title: 'Action de glisser à gauche',
                  current: swipeLeft,
                  onPicked: (v) =>
                      ref.read(librarySwipeLeftProvider.notifier).set(v),
                ),
              ),
              ListTile(
                leading: const Icon(Broken.arrow_right_2),
                title: const Text('Action de glisser à droite'),
                subtitle: Text(
                  kLibrarySwipeActions[swipeRight],
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickSwipe(
                  context,
                  ref,
                  title: 'Action de glisser à droite',
                  current: swipeRight,
                  onPicked: (v) =>
                      ref.read(librarySwipeRightProvider.notifier).set(v),
                ),
              ),
              ListTile(
                leading: const Icon(Broken.copy_success),
                title: const Text('Marquer un chapitre dupliqué comme lu'),
                subtitle: Text(
                  markDuplicate == 0 ? 'Aucun(e)' : 'Activé',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickMarkDuplicate(context, ref, markDuplicate),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.eye_slash),
                value: hideMissing,
                title: const Text('Masquer les indicateurs de chapitre manquants'),
                onChanged: (v) =>
                    ref.read(libraryHideMissingChaptersProvider.notifier).set(v),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────

  void _pickInterval(BuildContext context, WidgetRef ref, int current) {
    _radioSheet<int>(
      context,
      title: 'Mises à jour automatiques',
      options: kLibraryUpdateIntervalOptions.keys.toList(),
      current: current,
      labelOf: (e) => kLibraryUpdateIntervalOptions[e] ?? 'Manuelle',
      valueOf: (e) => e,
      onPicked: (v) => ref.read(libraryUpdateIntervalProvider.notifier).set(v),
    );
  }

  void _pickSmartUpdate(BuildContext context, WidgetRef ref, int current) {
    _radioSheet<int>(
      context,
      title: 'Mise à jour intelligente',
      options: List.generate(kLibrarySmartUpdateLabels.length, (i) => i),
      current: current,
      labelOf: (i) => kLibrarySmartUpdateLabels[i],
      valueOf: (i) => i,
      onPicked: (v) => ref.read(librarySmartUpdateProvider.notifier).set(v),
    );
  }

  void _pickMarkDuplicate(BuildContext context, WidgetRef ref, int current) {
    _radioSheet<int>(
      context,
      title: 'Marquer un chapitre dupliqué comme lu',
      options: const [0, 1],
      current: current,
      labelOf: (i) => i == 0 ? 'Aucun(e)' : 'Marquer comme lu',
      valueOf: (i) => i,
      onPicked: (v) =>
          ref.read(libraryMarkDuplicateReadProvider.notifier).set(v),
    );
  }

  void _pickSwipe(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int current,
    required ValueChanged<int> onPicked,
  }) {
    _radioSheet<int>(
      context,
      title: title,
      options: List.generate(kLibrarySwipeActions.length, (i) => i),
      current: current,
      labelOf: (i) => kLibrarySwipeActions[i],
      valueOf: (i) => i,
      onPicked: onPicked,
    );
  }

  void _pickRestrictions(
    BuildContext context,
    WidgetRef ref, {
    required bool wifiOnly,
    required bool chargingOnly,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Restrictions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: wifiOnly,
                contentPadding: EdgeInsets.zero,
                title: const Text('Uniquement en Wi-Fi'),
                onChanged: (v) {
                  setState(() => wifiOnly = v ?? false);
                  ref.read(libraryUpdateWifiOnlyProvider.notifier).set(
                        v ?? false,
                      );
                },
              ),
              CheckboxListTile(
                value: chargingOnly,
                contentPadding: EdgeInsets.zero,
                title: const Text('Uniquement en charge'),
                onChanged: (v) {
                  setState(() => chargingOnly = v ?? false);
                  ref.read(libraryUpdateChargingOnlyProvider.notifier).set(
                        v ?? false,
                      );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Human-readable summary of an include/exclude category selection.
  String _describeCategories(WidgetRef ref, Set<int> selected) {
    if (selected.isEmpty) return 'Tout';
    final names = <String>[];
    for (final id in selected) {
      final category = isar.categorys.getSync(id);
      if (category != null) names.add(category.name ?? '');
    }
    if (names.isEmpty) return 'Tout';
    return names.join(', ');
  }

  /// Mihon-style category picker: one list, two independent columns of
  /// checkboxes for "Inclure" and "Exclure". A category can only appear in one
  /// column at a time — ticking it in one clears the other, mirroring Mihon.
  void _pickCategories(BuildContext context, WidgetRef ref) {
    final categories = isar.categorys.where().sortByName().findAllSync();
    var include = ref.read(libraryUpdateIncludeCategoriesProvider);
    var exclude = ref.read(libraryUpdateExcludeCategoriesProvider);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Catégories'),
            contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            content: SizedBox(
              width: 340,
              child: categories.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune catégorie.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: const [
                              Expanded(
                                child: Text(
                                  'Inclure',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Exclure',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 8),
                        for (final category in categories)
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: include.contains(category.id),
                                  title: Text(
                                    category.name ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onChanged: (v) => setState(() {
                                    if (v ?? false) {
                                      include = {...include, category.id!};
                                      exclude = {...exclude}..remove(category.id);
                                    } else {
                                      include = {...include}..remove(category.id);
                                    }
                                  }),
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: exclude.contains(category.id),
                                  title: const SizedBox.shrink(),
                                  onChanged: (v) => setState(() {
                                    if (v ?? false) {
                                      exclude = {...exclude, category.id!};
                                      include = {...include}..remove(category.id);
                                    } else {
                                      exclude = {...exclude}..remove(category.id);
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref
                      .read(libraryUpdateIncludeCategoriesProvider.notifier)
                      .set(include);
                  ref
                      .read(libraryUpdateExcludeCategoriesProvider.notifier)
                      .set(exclude);
                  Navigator.pop(ctx);
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _pickDefaultCategory(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    const options = ['Défaut', 'Aucun(e)'];
    _radioSheet<String>(
      context,
      title: 'Catégorie par défaut',
      options: options,
      current: current,
      labelOf: (e) => e,
      valueOf: (e) => e,
      onPicked: (v) => ref.read(defaultCategoryStateProvider.notifier).set(v),
    );
  }
}

// ── Shared radio bottom sheet ────────────────────────────────────────────────

void _radioSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T current,
  required String Function(T) labelOf,
  required T Function(T) valueOf,
  required ValueChanged<T> onPicked,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: RadioGroup<T>(
        groupValue: current,
        onChanged: (v) {
          if (v == null) return;
          onPicked(valueOf(v));
          Navigator.pop(ctx);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map(
                      (o) => RadioListTile<T>(
                        value: o,
                        title: Text(labelOf(o)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Section header ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}
