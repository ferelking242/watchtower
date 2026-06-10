import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/app_font_family.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/follow_system_theme_button.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/date.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/date_format_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/pure_black_dark_mode_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/blend_level_slider.dart';
import 'package:watchtower/modules/more/settings/appearance/widgets/dark_mode_button.dart';
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
      appBar: AppBar(title: Text(l10n!.appearance)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SettingsSection(
              title: l10n.theme,
              children: [
                const _ThemeModeBar(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Theme mode segmented bar — Light | System | Dark (Mihon style)
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeModeBar extends ConsumerWidget {
  const _ThemeModeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followSystem = ref.watch(followSystemThemeStateProvider);
    final isDark = ref.watch(themeModeStateProvider);
    final int mode = followSystem ? 1 : (isDark ? 2 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          selectedForegroundColor: Theme.of(context).colorScheme.primary,
        ),
        segments: const [
          ButtonSegment(
            value: 0,
            icon: Icon(Icons.light_mode_rounded, size: 18),
            label: Text('Clair'),
          ),
          ButtonSegment(
            value: 1,
            icon: Icon(Icons.brightness_auto_rounded, size: 18),
            label: Text('Système'),
          ),
          ButtonSegment(
            value: 2,
            icon: Icon(Icons.dark_mode_rounded, size: 18),
            label: Text('Sombre'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) {
          final m = s.first;
          if (m == 1) {
            ref.read(followSystemThemeStateProvider.notifier).set(true);
          } else {
            if (followSystem) {
              ref.read(followSystemThemeStateProvider.notifier).set(false);
            }
            if (m == 0) {
              ref.read(themeModeStateProvider.notifier).setLightTheme();
            } else {
              ref.read(themeModeStateProvider.notifier).setDarkTheme();
            }
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language picker dialog — 3-per-row grid with flag + search
// ─────────────────────────────────────────────────────────────────────────────

class _LanguagePickerDialog extends StatefulWidget {
  final Locale currentLocale;
  final void Function(Locale) onSelected;
  final String cancelLabel;

  const _LanguagePickerDialog({
    required this.currentLocale,
    required this.onSelected,
    required this.cancelLabel,
  });

  @override
  State<_LanguagePickerDialog> createState() => _LanguagePickerDialogState();
}

class _LanguagePickerDialogState extends State<_LanguagePickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locales = AppLocalizations.supportedLocales.where((l) {
      final name = completeLanguageName(l.toLanguageTag()).toLowerCase();
      return name.contains(_search.toLowerCase());
    }).toList();

    return AlertDialog(
      title: const Text('Langue de l\'app'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 440,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.55,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: locales.length,
                itemBuilder: (ctx, i) {
                  final locale = locales[i];
                  final name =
                      completeLanguageName(locale.toLanguageTag());
                  final flag = langFlagEmoji(locale.toLanguageTag());
                  final isSelected = locale == widget.currentLocale;
                  return GestureDetector(
                    onTap: () {
                      widget.onSelected(locale);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : cs.outline.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(flag,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 3),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? cs.primary
                                    : cs.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
          child: Text(widget.cancelLabel,
              style: TextStyle(color: cs.primary)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Font picker dialog — 3-per-row grid, each name in its own typeface
// ─────────────────────────────────────────────────────────────────────────────

class _FontPickerDialog extends StatefulWidget {
  final String? currentFont;
  final String defaultLabel;
  final String cancelLabel;
  final void Function(String?) onSelected;

  const _FontPickerDialog({
    required this.currentFont,
    required this.defaultLabel,
    required this.cancelLabel,
    required this.onSelected,
  });

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allFonts = GoogleFonts.asMap().entries.toList();
    final fonts = _search.isEmpty
        ? allFonts
        : allFonts
            .where((e) =>
                e.key.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return AlertDialog(
      title: const Text('Police'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 440,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Rechercher une police...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: fonts.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    final isSelected = widget.currentFont == null;
                    return GestureDetector(
                      onTap: () {
                        widget.onSelected(null);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : cs.outline.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.defaultLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color:
                                  isSelected ? cs.primary : cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }
                  final entry = fonts[i - 1];
                  final fontName = entry.key;
                  final fontStyle = entry.value();
                  final isSelected =
                      widget.currentFont == fontStyle.fontFamily;
                  return GestureDetector(
                    onTap: () {
                      widget.onSelected(fontStyle.fontFamily);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : cs.outline.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            fontName,
                            style: fontStyle.copyWith(
                              fontSize: 11,
                              color:
                                  isSelected ? cs.primary : cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
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
          child: Text(widget.cancelLabel,
              style: TextStyle(color: cs.primary)),
        ),
      ],
    );
  }
}
