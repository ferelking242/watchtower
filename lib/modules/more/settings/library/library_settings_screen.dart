import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

/// Library settings, modelled on Mihon's "Bibliothèque" section.
class LibrarySettingsScreen extends ConsumerWidget {
  const LibrarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
      if (wifiOnly) l10n.only_on_wifi,
      if (chargingOnly) l10n.library_settings_charging_only,
    ];

    return SettingsSubpageScaffold(
      title: l10n.library,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Catégories ─────────────────────────────────────────────
              _Section(icon: Broken.category, label: l10n.categories),
              ListTile(
                leading: const Icon(Broken.category_2),
                title: Text(l10n.categories),
                subtitle: Text(
                  l10n.library_settings_categories_subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/categories', extra: (true, 0)),
              ),
              ListTile(
                leading: const Icon(Broken.edit_2),
                title: Text(l10n.edit_categories),
                subtitle: Text(
                  l10n.library_settings_edit_categories_subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/categories', extra: (false, 0)),
              ),
              ListTile(
                leading: const Icon(Broken.bookmark),
                title: Text(l10n.library_settings_default_category),
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
                title: Text(l10n.library_settings_per_category_sort),
                onChanged: (v) =>
                    ref.read(libraryPerCategorySortProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Mises à jour ───────────────────────────────────────────
              _Section(icon: Broken.refresh, label: l10n.library_settings_section_updates),
              ListTile(
                leading: const Icon(Broken.refresh_circle),
                title: Text(l10n.library_settings_section_updates),
                subtitle: Text(
                  libraryUpdateIntervalLabel(l10n, interval),
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
                title: Text(l10n.library_settings_update_restrictions),
                subtitle: Text(
                  l10n.library_settings_restrictions_summary(
                    restrictions.isEmpty
                        ? l10n.library_settings_swipe_none
                        : restrictions.join(', '),
                  ),
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
                title: Text(l10n.categories),
                subtitle: Text(
                  l10n.library_settings_categories_summary(
                    _describeCategories(l10n, ref, includeCats),
                    _describeCategories(l10n, ref, excludeCats),
                  ),
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
                title: Text(l10n.library_settings_auto_refresh_metadata),
                onChanged: (v) =>
                    ref.read(libraryAutoRefreshMetadataProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.image),
                value: checkCover,
                title: Text(l10n.library_settings_check_new_cover),
                onChanged: (v) =>
                    ref.read(libraryCheckNewCoverProvider.notifier).set(v),
              ),
              ListTile(
                leading: const Icon(Broken.magicpen),
                title: Text(l10n.settings_idx_title_mise_a_jour_intelligente),
                subtitle: Text(
                  librarySmartUpdateLabel(l10n, smartUpdate),
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
                title: Text(l10n.library_settings_unread_badge),
                onChanged: (v) =>
                    ref.read(libraryUnreadBadgeProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Comportement ───────────────────────────────────────────
              _Section(icon: Broken.task, label: l10n.library_settings_section_behavior),
              ListTile(
                leading: const Icon(Broken.arrow_left_2),
                title: Text(l10n.library_settings_swipe_left),
                subtitle: Text(
                  librarySwipeActionLabel(l10n, swipeLeft),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickSwipe(
                  context,
                  ref,
                  title: l10n.library_settings_swipe_left,
                  current: swipeLeft,
                  onPicked: (v) =>
                      ref.read(librarySwipeLeftProvider.notifier).set(v),
                ),
              ),
              ListTile(
                leading: const Icon(Broken.arrow_right_2),
                title: Text(l10n.library_settings_swipe_right),
                subtitle: Text(
                  librarySwipeActionLabel(l10n, swipeRight),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickSwipe(
                  context,
                  ref,
                  title: l10n.library_settings_swipe_right,
                  current: swipeRight,
                  onPicked: (v) =>
                      ref.read(librarySwipeRightProvider.notifier).set(v),
                ),
              ),
              ListTile(
                leading: const Icon(Broken.copy_success),
                title: Text(l10n.library_settings_mark_duplicate),
                subtitle: Text(
                  markDuplicate == 0
                      ? l10n.library_settings_swipe_none
                      : l10n.on,
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
                title: Text(l10n.library_settings_hide_missing),
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
      title: context.l10n.library_settings_section_updates,
      options: kLibraryUpdateIntervalOptions,
      current: current,
      labelOf: (e) => libraryUpdateIntervalLabel(context.l10n, e),
      valueOf: (e) => e,
      onPicked: (v) => ref.read(libraryUpdateIntervalProvider.notifier).set(v),
    );
  }

  void _pickSmartUpdate(BuildContext context, WidgetRef ref, int current) {
    _radioSheet<int>(
      context,
      title: context.l10n.settings_idx_title_mise_a_jour_intelligente,
      options: kLibrarySmartUpdateValues,
      current: current,
      labelOf: (i) => librarySmartUpdateLabel(context.l10n, i),
      valueOf: (i) => i,
      onPicked: (v) => ref.read(librarySmartUpdateProvider.notifier).set(v),
    );
  }

  void _pickMarkDuplicate(BuildContext context, WidgetRef ref, int current) {
    _radioSheet<int>(
      context,
      title: context.l10n.library_settings_mark_duplicate,
      options: const [0, 1],
      current: current,
      labelOf: (i) => i == 0
          ? context.l10n.library_settings_swipe_none
          : context.l10n.library_settings_mark_as_read,
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
      options: kLibrarySwipeActions,
      current: current,
      labelOf: (i) => librarySwipeActionLabel(context.l10n, i),
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
          title: Text(context.l10n.library_settings_restrictions),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: wifiOnly,
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.only_on_wifi),
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
                title: Text(context.l10n.library_settings_charging_only),
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
              child: Text(context.l10n.plugins_action_close),
            ),
          ],
        ),
      ),
    );
  }

  /// Human-readable summary of an include/exclude category selection.
  String _describeCategories(
    AppLocalizations l10n,
    WidgetRef ref,
    Set<int> selected,
  ) {
    if (selected.isEmpty) return l10n.library_settings_everything;
    final names = <String>[];
    for (final id in selected) {
      final category = isar.categorys.getSync(id);
      if (category != null) names.add(category.name ?? '');
    }
    if (names.isEmpty) return l10n.library_settings_everything;
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
            title: Text(context.l10n.categories),
            contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            content: SizedBox(
              width: 340,
              child: categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.l10n.library_settings_no_category),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.l10n.library_settings_include,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  context.l10n.library_settings_exclude,
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
                child: Text(context.l10n.browse_validate),
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
    const options = ['Default', 'None'];
    _radioSheet<String>(
      context,
      title: context.l10n.library_settings_default_category,
      options: options,
      current: current,
      labelOf: (e) => e == 'Default'
          ? context.l10n.nav_layout_default
          : context.l10n.library_settings_swipe_none,
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
    // Scroll-controlled with a height cap: the default half-screen sheet
    // clipped the tail of a 10-option list, so the last actions (Supprimer,
    // Marquer comme non lu) could not be reached at all.
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
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
                  padding: const EdgeInsets.only(bottom: 12),
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
