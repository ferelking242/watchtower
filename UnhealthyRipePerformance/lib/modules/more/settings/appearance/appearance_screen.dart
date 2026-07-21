import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/app_font_family.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/toggle_theme_mode_container.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/date_format_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/blend_level_slider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/theme_selector.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/utils/language.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

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

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              title,
              style: TextStyle(fontSize: 13, color: context.primaryColor),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context);
    final pureBlackDarkMode = ref.watch(pureBlackDarkModeStateProvider);
    final isDarkTheme = ref.watch(themeModeStateProvider);
    bool followSystemTheme = ref.watch(followSystemThemeStateProvider);


    return Scaffold(
      appBar: AppBar(
        title: Text(l10n!.appearance),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SettingsSection(
              title: l10n.theme,
              children: [
                LayoutBuilder(builder: (ctx, c) => ToggleThemeModeContainer(maxWidth: c.maxWidth)),
                const ThemeSelector(),
                if (isDarkTheme)
                  SwitchListTile(
                    title: Text(l10n.pure_black_dark_mode),
                    value: pureBlackDarkMode,
                    onChanged: (value) {
                      ref
                          .read(pureBlackDarkModeStateProvider.notifier)
                          .set(value);
                    },
                  ),
                if (!pureBlackDarkMode || !isDarkTheme)
                  const BlendLevelSlider(),
              ],
            ),
            SettingsSection(
              title: l10n.appearance,
              children: [
                _buildLanguageTile(context, ref, l10n),
                _buildFontTile(context, ref, l10n),
                ListTile(
                  title: Text(l10n.reorder_navigation),
                  subtitle: Text(
                    l10n.reorder_navigation_description,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.secondaryColor,
                    ),
                  ),
                  onTap: () {
                    context.push("/customNavigationSettings");
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('Interface & Effets'),
                  subtitle: Text(
                    'Carousel, flou, animations et effets visuels',
                    style: TextStyle(fontSize: 11, color: context.secondaryColor),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/uiSettings'),
                ),
              ],
            ),

            SettingsSection(
              title: l10n.timestamp,
              children: [
                _buildRelativeTimestampTile(context, ref, l10n),
                _buildDateFormatTile(context, ref, l10n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Carousel style dialog ────────────────────────────────────────────────

  void _showCarouselStyleDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(carouselStyleProvider);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Carousel Style'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              carouselStyleLabels.length,
              (i) => RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: i,
                groupValue: current,
                title: Text(carouselStyleLabels[i]),
                onChanged: (v) {
                  if (v != null) {
                    ref.read(carouselStyleProvider.notifier).set(v);
                  }
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final l10nLocale = ref.watch(l10nLocaleStateProvider);
    return ListTile(
      title: Text(l10n.app_language),
      subtitle: Text(
        completeLanguageName(l10nLocale.toLanguageTag()),
        style: TextStyle(fontSize: 11, color: context.secondaryColor),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => _LanguagePickerDialog(
            currentLocale: l10nLocale,
            onSelected: (locale) {
              ref.read(l10nLocaleStateProvider.notifier).setLocale(locale);
            },
            cancelLabel: l10n.cancel,
          ),
        );
      },
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
      title: Text(context.l10n.font),
      subtitle: Text(
        appFontFamilySub,
        style: TextStyle(fontSize: 11, color: context.secondaryColor),
      ),
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

  Widget _buildRelativeTimestampTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final relativeTimestamps = ref.watch(relativeTimesTampsStateProvider);
    return ListTile(
      title: Text(l10n.relative_timestamp),
      subtitle: Text(
        relativeTimestampsList(context)[relativeTimestamps],
        style: TextStyle(fontSize: 11, color: context.secondaryColor),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.relative_timestamp),
              content: SizedBox(
                width: context.width(0.8),
                child: RadioGroup(
                  groupValue: relativeTimestamps,
                  onChanged: (value) {
                    ref
                        .read(relativeTimesTampsStateProvider.notifier)
                        .set(value!);
                    Navigator.pop(context);
                  },
                  child: SuperListView.builder(
                    shrinkWrap: true,
                    itemCount: relativeTimestampsList(context).length,
                    itemBuilder: (context, index) {
                      return RadioListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.all(0),
                        value: index,
                        title: Row(
                          children: [
                            Text(relativeTimestampsList(context)[index]),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                      },
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(color: context.primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateFormatTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final dateFormatState = ref.watch(dateFormatStateProvider);
    return ListTile(
      title: Text(l10n.date_format),
      subtitle: Text(
        "$dateFormatState (${dateFormat(context: context, DateTime.now().millisecondsSinceEpoch.toString(), useRelativeTimesTamps: false, dateFormat: dateFormatState, ref: ref)})",
        style: TextStyle(fontSize: 11, color: context.secondaryColor),
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.date_format),
              content: SizedBox(
                width: context.width(0.8),
                child: RadioGroup(
                  groupValue: dateFormatState,
                  onChanged: (value) {
                    ref.read(dateFormatStateProvider.notifier).set(value!);
                    Navigator.pop(context);
                  },
                  child: SuperListView.builder(
                    shrinkWrap: true,
                    itemCount: dateFormatsList.length,
                    itemBuilder: (context, index) {
                      return RadioListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.all(0),
                        value: dateFormatsList[index],
                        title: Row(
                          children: [
                            Text(
                              "${dateFormatsList[index]} (${dateFormat(context: context, DateTime.now().millisecondsSinceEpoch.toString(), useRelativeTimesTamps: false, dateFormat: dateFormatsList[index], ref: ref)})",
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                      },
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(color: context.primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Language picker dialog
// ---------------------------------------------------------------------------

class _LanguagePickerDialog extends StatelessWidget {
  const _LanguagePickerDialog({
    required this.currentLocale,
    required this.onSelected,
    required this.cancelLabel,
  });

  final Locale currentLocale;
  final ValueChanged<Locale> onSelected;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.supportedLocales;
    return AlertDialog(
      title: const Text('Language'),
      content: SizedBox(
        width: double.maxFinite,
        child: SuperListView.builder(
          shrinkWrap: true,
          itemCount: locales.length,
          itemBuilder: (context, index) {
            final locale = locales[index];
            final tag = locale.toLanguageTag();
            final flag = langFlagEmoji(tag);
            final name = completeLanguageName(tag);
            final selected = locale.languageCode == currentLocale.languageCode &&
                locale.countryCode == currentLocale.countryCode;
            return RadioListTile<Locale>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: locale,
              groupValue: selected ? locale : null,
              title: Text('$flag  $name'),
              onChanged: (_) {
                onSelected(locale);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            cancelLabel,
            style: TextStyle(color: context.primaryColor),
          ),
        ),
      ],
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
      title: const Text('Font'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search fonts…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SuperListView.builder(
                itemCount: _filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Default option
                    return RadioListTile<String?>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: null,
                      groupValue: widget.currentFont,
                      title: Text(widget.defaultLabel),
                      onChanged: (_) {
                        widget.onSelected(null);
                        Navigator.pop(context);
                      },
                    );
                  }
                  final entry = _filtered[index - 1];
                  final fontFamily = entry.value().fontFamily!;
                  return RadioListTile<String?>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: fontFamily,
                    groupValue: widget.currentFont,
                    title: Text(entry.key),
                    onChanged: (_) {
                      widget.onSelected(fontFamily);
                      Navigator.pop(context);
                    },
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

