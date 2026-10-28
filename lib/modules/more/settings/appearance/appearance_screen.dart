// Affichage (formerly Apparence). First entries are the app language and the
// tablet mode, mirroring Mihon's Display section order.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/more/settings/appearance/app_language_screen.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/app_font_family.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/date_format_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/display_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/blend_level_slider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/theme_selector.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/toggle_theme_mode_container.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

final navigationItems = {
  "/WatchtowerHome": "Accueil",
  "/Library": "Bibliothèque",
  "/MangaLibrary": "Manga",
  "/AnimeLibrary": "Watch",
  "/NovelLibrary": "Novel",
  "/MusicLibrary": "Music",
  "/GameLibrary": "Games",
  "/updates": "Updates",
  "/history": "History",
  "/browse": "Browse",
  "/more": "More",
  "/trackerLibrary": "Tracking",
};

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final pureBlackDarkMode = ref.watch(pureBlackDarkModeStateProvider);
    final isDarkTheme = ref.watch(themeModeStateProvider);
    final tabletMode = ref.watch(tabletModeProvider);
    final renderImages = ref.watch(renderDescriptionImagesProvider);
    final dateFormatState = ref.watch(dateFormatStateProvider);
    final relativeTimestamps = ref.watch(relativeTimesTampsStateProvider);
    final appLanguage = ref.watch(appLanguageOverrideProvider);
    final localeLabel = appLanguage == null
        ? 'Système (par défaut)'
        : (AppLanguageScreen.labels[appLanguage.languageCode] ??
              appLanguage.languageCode.toUpperCase());

    return SettingsSubpageScaffold(
      title: 'Affichage',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Langue de l'application ────────────────────────────────
              ListTile(
                leading: const Icon(Broken.translate),
                title: const Text("Langue de l'application"),
                subtitle: Text(
                  localeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/appLanguage'),
              ),

              // ── Mode tablette ──────────────────────────────────────────
              ListTile(
                leading: const Icon(Broken.monitor_mobbile),
                title: const Text('Mode tablette'),
                subtitle: Text(
                  tabletModeLabel(tabletMode),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickTabletMode(context, ref, tabletMode),
              ),

              // ── Format de date ─────────────────────────────────────────
              ListTile(
                leading: const Icon(Broken.calendar),
                title: const Text('Format de date'),
                subtitle: Text(
                  '$dateFormatState (${dateFormat(context: context, DateTime.now().millisecondsSinceEpoch.toString(), useRelativeTimesTamps: false, dateFormat: dateFormatState, ref: ref)})',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () =>
                    _pickDateFormat(context, ref, l10n, dateFormatState),
              ),

              // ── Durées relatives ───────────────────────────────────────
              ListTile(
                leading: const Icon(Broken.timer),
                title: const Text('Durées relatives'),
                subtitle: Text(
                  relativeTimestampsList(context)[relativeTimestamps],
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _pickRelativeTimestamp(
                  context,
                  ref,
                  l10n,
                  relativeTimestamps,
                ),
              ),

              // ── Images dans les descriptions ───────────────────────────
              SwitchListTile(
                secondary: const Icon(Broken.image),
                value: renderImages,
                title: const Text(
                  'Rendre les images dans les descriptions de mangas',
                ),
                onChanged: (v) =>
                    ref.read(renderDescriptionImagesProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Thème ──────────────────────────────────────────────────
              _Section(icon: Broken.paintbucket, label: l10n.theme),

              // Sliding bar pushed lower, with rounded ends.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: LayoutBuilder(
                  builder: (ctx, c) => ToggleThemeModeContainer(
                    maxWidth: c.maxWidth,
                  ),
                ),
              ),

              // Theme colours memorised in a phone-shaped preview card.
              const ThemeSelector(),

              if (isDarkTheme)
                SwitchListTile(
                  secondary: const Icon(Broken.moon),
                  title: Text(l10n.pure_black_dark_mode),
                  value: pureBlackDarkMode,
                  onChanged: (value) {
                    ref
                        .read(pureBlackDarkModeStateProvider.notifier)
                        .set(value);
                  },
                ),
              if (!pureBlackDarkMode || !isDarkTheme) const BlendLevelSlider(),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Interface ──────────────────────────────────────────────
              _Section(icon: Broken.setting_2, label: 'Interface'),
              _buildFontTile(context, ref, l10n),
              ListTile(
                leading: const Icon(Broken.magic_star),
                title: const Text('Interface & Effets'),
                subtitle: Text(
                  'Carousel, flou, animations et effets visuels',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/uiSettings'),
              ),
              ListTile(
                leading: const Icon(Broken.category),
                title: Text(l10n.reorder_navigation),
                subtitle: Text(
                  l10n.reorder_navigation_description,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.secondaryColor,
                  ),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/customNavigationSettings'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _pickTabletMode(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (v) {
            if (v == null) return;
            ref.read(tabletModeProvider.notifier).set(v);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Mode tablette',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ...kTabletModeOptions.map(
                (o) => RadioListTile<String>(
                  value: o.$1,
                  title: Text(o.$2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final appFontFamily = ref.watch(appFontFamilyProvider);
    final appFontFamilySub = appFontFamily == null
        ? context.l10n.default0
        : GoogleFonts.asMap().entries
              .toList()
              .firstWhere(
                (element) => element.value().fontFamily! == appFontFamily,
              )
              .key;
    return ListTile(
      leading: const Icon(Broken.text),
      title: Text(context.l10n.font),
      subtitle: Text(
        appFontFamilySub,
        style: TextStyle(fontSize: 11, color: context.secondaryColor),
      ),
      trailing: const Icon(Broken.arrow_right_2),
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => _FontPickerDialog(
            currentFont: appFontFamily,
            defaultLabel: l10n.default0,
            cancelLabel: l10n.cancel,
            onSelected: (value) {
              ref.read(appFontFamilyProvider.notifier).set(value);
            },
          ),
        );
      },
    );
  }

  void _pickRelativeTimestamp(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<int>(
          groupValue: current,
          onChanged: (value) {
            if (value == null) return;
            ref.read(relativeTimesTampsStateProvider.notifier).set(value);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l10n.relative_timestamp,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...List.generate(
                relativeTimestampsList(context).length,
                (i) => RadioListTile<int>(
                  value: i,
                  title: Text(relativeTimestampsList(context)[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickDateFormat(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value == null) return;
            ref.read(dateFormatStateProvider.notifier).set(value);
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l10n.date_format,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: dateFormatsList
                      .map(
                        (f) => RadioListTile<String>(
                          value: f,
                          title: Text(
                            '$f (${dateFormat(context: context, DateTime.now().millisecondsSinceEpoch.toString(), useRelativeTimesTamps: false, dateFormat: f, ref: ref)})',
                          ),
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

// ---------------------------------------------------------------------------
// Font picker dialog
// ---------------------------------------------------------------------------

class _FontPickerDialog extends StatefulWidget {
  const _FontPickerDialog({
    required this.currentFont,
    required this.defaultLabel,
    required this.cancelLabel,
    required this.onSelected,
  });

  final String? currentFont;
  final String defaultLabel;
  final String cancelLabel;
  final ValueChanged<String?> onSelected;

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  late final TextEditingController _search;
  late List<MapEntry<String, dynamic>> _all;
  late List<MapEntry<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _all = GoogleFonts.asMap().entries.toList();
    _filtered = _all;
    _search = TextEditingController()
      ..addListener(() {
        final q = _search.text.toLowerCase();
        setState(() {
          _filtered = q.isEmpty
              ? _all
              : _all.where((e) => e.key.toLowerCase().contains(q)).toList();
        });
      });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Police'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Rechercher une police…',
                prefixIcon: Icon(Broken.search_normal),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SuperListView.builder(
                itemCount: _filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return RadioGroup<String?>(
                      groupValue: widget.currentFont,
                      onChanged: (_) {
                        widget.onSelected(null);
                        Navigator.pop(context);
                      },
                      child: RadioListTile<String?>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: null,
                        title: Text(widget.defaultLabel),
                      ),
                    );
                  }
                  final entry = _filtered[index - 1];
                  final fontFamily = entry.value().fontFamily!;
                  return RadioGroup<String?>(
                    groupValue: widget.currentFont,
                    onChanged: (_) {
                      widget.onSelected(fontFamily);
                      Navigator.pop(context);
                    },
                    child: RadioListTile<String?>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: fontFamily,
                      title: Text(entry.key),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.cancelLabel,
            style: TextStyle(color: context.primaryColor),
          ),
        ),
      ],
    );
  }
}
