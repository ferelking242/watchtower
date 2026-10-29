// Reader (manga) settings, laid out like Mihon's "Lecteur" screen.
//
// Sections follow Mihon's order: display basics, then the per-mode blocks
// (Pages, Bande continue), Navigation and Actions. Options that have no field
// in the Isar settings model are stored through `reader_prefs_provider`.

import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final defaultReadingMode = ref.watch(defaultReadingModeStateProvider);
    final animatePageTransitions = ref.watch(
      animatePageTransitionsStateProvider,
    );
    final doubleTapAnimationSpeed = ref.watch(
      doubleTapAnimationSpeedStateProvider,
    );
    final pagePreloadAmount = ref.watch(pagePreloadAmountStateProvider);
    final scaleType = ref.watch(scaleTypeStateProvider);
    final backgroundColor = ref.watch(backgroundColorStateProvider);
    final usePageTapZones = ref.watch(usePageTapZonesStateProvider);
    final fullScreenReader = ref.watch(fullScreenReaderStateProvider);
    final cropBorders = ref.watch(cropBordersStateProvider);
    final keepScreenOn = ref.watch(keepScreenOnReaderStateProvider);
    final showPageGaps = ref.watch(showPageGapsStateProvider);
    final webtoonSidePadding = ref.watch(webtoonSidePaddingStateProvider);
    final navigationLayout = ref.watch(readerNavigationLayoutStateProvider);
    final volumeButtonNav = ref.watch(volumeButtonNavigationStateProvider);
    final invertVolumeButtonNav = ref.watch(
      invertVolumeButtonNavigationStateProvider,
    );
    final showPagesNumber =
        (ref.watch(showPagesNumberStateProvider) as bool?) ?? true;

    final showReadingMode = ref.watch(showReadingModeProvider);
    final showTapZonesOverlay = ref.watch(showTapZonesOverlayProvider);
    final loadAheadOnlyOnWifi = ref.watch(loadAheadOnlyOnWifiProvider);
    final rotation = ref.watch(readerRotationProvider);
    final cutout = ref.watch(readerCutoutProvider);
    final einkFlash = ref.watch(einkFlashOnPageChangeProvider);
    final skipRead = ref.watch(skipReadChaptersProvider);
    final skipFiltered = ref.watch(skipFilteredChaptersProvider);
    final skipDuplicate = ref.watch(skipDuplicateChaptersProvider);
    final alwaysShowChapterTransition = ref.watch(
      alwaysShowChapterTransitionProvider,
    );
    final invertTapZones = ref.watch(invertPageTapZonesProvider);
    final zoomStart = ref.watch(zoomStartPositionProvider);
    final panorama = ref.watch(panoramaImagesProvider);
    final splitWide = ref.watch(splitWidePagesProvider);
    final rotateWide = ref.watch(rotateWidePagesProvider);
    final doubleTapZoomOut = ref.watch(doubleTapZoomOutProvider);
    final menuHideSensitivity = ref.watch(
      continuousMenuHideSensitivityProvider,
    );
    final verticalNavigator = ref.watch(verticalChapterNavigatorProvider);
    final longPressActions = ref.watch(longPressActionsProvider);
    final savePagesSeparately = ref.watch(savePagesInSeparateFoldersProvider);

    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return SettingsSubpageScaffold(
      title: l10n.reader_manga,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Général ────────────────────────────────────────────────
              _Tile(
                icon: Broken.book,
                title: l10n.default_reading_mode,
                value: getReaderModeName(defaultReadingMode, context),
                onTap: () => _pickReaderMode(context, ref, defaultReadingMode),
              ),
              _Tile(
                icon: Broken.timer_1,
                title: l10n.double_tap_animation_speed,
                value: getDoubleTapAnimationSpeedName(
                  doubleTapAnimationSpeed,
                  context,
                ),
                onTap: () => _pickDoubleTapSpeed(
                  context,
                  ref,
                  doubleTapAnimationSpeed,
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.book_1),
                value: showReadingMode,
                title: const Text('Afficher le mode de lecture'),
                subtitle: const Text(
                  "Affiche la liste des modes de lecture à l'ouverture du lecteur",
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(showReadingModeProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.mouse),
                value: showTapZonesOverlay,
                title: const Text('Afficher les zones tactiles (superposition)'),
                subtitle: const Text(
                  "Affichage bref à l'ouverture du lecteur",
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(showTapZonesOverlayProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.wifi),
                value: loadAheadOnlyOnWifi,
                title: const Text('Précharger uniquement en Wi-Fi'),
                subtitle: const Text(
                  "Économise les données mobiles en ne chargeant que les pages "
                  'proches de celle en cours de lecture',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(loadAheadOnlyOnWifiProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.refresh),
                value: animatePageTransitions,
                title: Text(l10n.animate_page_transitions),
                onChanged: (v) =>
                    ref.read(animatePageTransitionsStateProvider.notifier).set(v),
              ),
              _Tile(
                icon: Broken.document_download,
                title: 'Nombre de pages à précharger',
                value: '$pagePreloadAmount',
                subtitle:
                    'Le nombre de pages à précharger pendant la lecture. Une '
                    'valeur plus élevée rend la lecture plus fluide, au prix '
                    "d'un cache plus grand et d'une consommation de données "
                    'plus importante.',
                slider: Slider(
                  min: 1,
                  max: 20,
                  divisions: 19,
                  value: pagePreloadAmount.toDouble().clamp(1, 20),
                  onChanged: (value) => ref
                      .read(pagePreloadAmountStateProvider.notifier)
                      .set(value.round()),
                ),
                onTap: () {},
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Affichage ──────────────────────────────────────────────
              _Section(icon: Broken.monitor, label: 'Affichage'),
              _Tile(
                icon: Broken.rotate_right,
                title: 'Rotation par défaut',
                value: optionLabel(kReaderRotationOptions, rotation),
                onTap: () => _pickString(
                  context,
                  ref,
                  title: 'Rotation par défaut',
                  options: kReaderRotationOptions,
                  current: rotation,
                  setter: (v) => ref.read(readerRotationProvider.notifier).set(v),
                ),
              ),
              _Tile(
                icon: Broken.paintbucket,
                title: l10n.background_color,
                value: getBackgroundColorName(backgroundColor, context),
                onTap: () =>
                    _pickBackgroundColor(context, ref, backgroundColor),
              ),
              if (isMobile)
                SwitchListTile(
                  secondary: const Icon(Broken.crop),
                  value: cutout,
                  title: const Text("Utiliser la zone de l'encoche"),
                  onChanged: (v) =>
                      ref.read(readerCutoutProvider.notifier).set(v),
                ),
              SwitchListTile(
                secondary: const Icon(Broken.sun_1),
                value: keepScreenOn,
                title: Text(l10n.keep_screen_on),
                onChanged: (v) =>
                    ref.read(keepScreenOnReaderStateProvider.notifier).set(v),
              ),
              if (kIsWeb || !isMobile)
                SwitchListTile(
                  secondary: const Icon(Broken.maximize_4),
                  value: fullScreenReader,
                  title: Text(l10n.fullscreen),
                  onChanged: (v) =>
                      ref.read(fullScreenReaderStateProvider.notifier).set(v),
                ),
              SwitchListTile(
                secondary: const Icon(Broken.mobile),
                value: showPagesNumber,
                title: const Text('Afficher le numéro des pages'),
                onChanged: (v) =>
                    ref.read(showPagesNumberStateProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── E-Ink ──────────────────────────────────────────────────
              _Section(icon: Broken.book_saved, label: 'E-Ink'),
              SwitchListTile(
                secondary: const Icon(Broken.flash_1),
                value: einkFlash,
                title: const Text('Flash lors du changement de page'),
                subtitle: const Text(
                  'Réduire le ghosting sur les écrans e-ink',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(einkFlashOnPageChangeProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── En cours ───────────────────────────────────────────────
              _Section(icon: Broken.book_1, label: 'En cours'),
              SwitchListTile(
                secondary: const Icon(Broken.tick_circle),
                value: skipRead,
                title: const Text('Passer les chapitres marqués comme lus'),
                onChanged: (v) =>
                    ref.read(skipReadChaptersProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.filter),
                value: skipFiltered,
                title: const Text('Passer les chapitres filtrés'),
                onChanged: (v) =>
                    ref.read(skipFilteredChaptersProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.copy),
                value: skipDuplicate,
                title: const Text('Ignorer les chapitres en double'),
                onChanged: (v) =>
                    ref.read(skipDuplicateChaptersProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.arrow_right_2),
                value: alwaysShowChapterTransition,
                title: const Text(
                  'Toujours afficher la transition entre les chapitres',
                ),
                onChanged: (v) => ref
                    .read(alwaysShowChapterTransitionProvider.notifier)
                    .set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Pages ──────────────────────────────────────────────────
              _Section(icon: Broken.document, label: 'Pages'),
              SwitchListTile(
                secondary: const Icon(Broken.mouse),
                value: usePageTapZones,
                title: Text(l10n.use_page_tap_zones),
                onChanged: (v) =>
                    ref.read(usePageTapZonesStateProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.refresh_left_square),
                value: invertTapZones,
                title: const Text('Inverser les zones tactiles'),
                onChanged: (v) =>
                    ref.read(invertPageTapZonesProvider.notifier).set(v),
              ),
              _Tile(
                icon: Broken.maximize_2,
                title: l10n.scale_type,
                value: getScaleTypeNames(context)[scaleType.index],
                onTap: () => _pickScaleType(context, ref, scaleType),
              ),
              _Tile(
                icon: Broken.search_zoom_in,
                title: 'Position du zoom initial',
                value: optionLabel(kZoomStartOptions, zoomStart),
                onTap: () => _pickString(
                  context,
                  ref,
                  title: 'Position du zoom initial',
                  options: kZoomStartOptions,
                  current: zoomStart,
                  setter: (v) =>
                      ref.read(zoomStartPositionProvider.notifier).set(v),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.crop),
                value: cropBorders,
                title: Text(l10n.crop_borders),
                onChanged: (v) =>
                    ref.read(cropBordersStateProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.maximize_3),
                value: panorama,
                title: const Text('Panoramique des images larges'),
                onChanged: (v) =>
                    ref.read(panoramaImagesProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.grid_5),
                value: splitWide,
                title: const Text('Diviser les pages larges'),
                onChanged: (v) =>
                    ref.read(splitWidePagesProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.rotate_right),
                value: rotateWide,
                title: const Text(
                  'Tourner les pages larges pour qu’elles rentrent',
                ),
                onChanged: (v) =>
                    ref.read(rotateWidePagesProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.search_zoom_in),
                value: doubleTapZoomOut,
                title: const Text('Désactiver le zoom arrière'),
                subtitle: const Text(
                  'Le double-clic ne fait plus que zoomer',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(doubleTapZoomOutProvider.notifier).set(v),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Bande continue ─────────────────────────────────────────
              _Section(icon: Broken.document_text, label: 'Bande continue'),
              SwitchListTile(
                secondary: const Icon(Broken.grid_4),
                value: showPageGaps,
                title: Text(l10n.show_page_gaps),
                onChanged: (v) =>
                    ref.read(showPageGapsStateProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.refresh_left_square),
                value: invertTapZones,
                title: const Text('Inverser les zones tactiles'),
                onChanged: (v) =>
                    ref.read(invertPageTapZonesProvider.notifier).set(v),
              ),
              _Tile(
                icon: Broken.arrow_swap,
                title: 'Décalage latéral',
                value: '$webtoonSidePadding%',
                slider: Slider(
                  min: 0,
                  max: 50,
                  divisions: 50,
                  value: webtoonSidePadding.toDouble(),
                  onChanged: (value) => ref
                      .read(webtoonSidePaddingStateProvider.notifier)
                      .set(value.toInt()),
                ),
                onTap: () {},
              ),
              _Tile(
                icon: Broken.mouse,
                title:
                    'Sensibilité pour masquer le menu lors du défilement',
                value:
                    kMenuHideSensitivityOptions[menuHideSensitivity].$2,
                onTap: () => _pickInt(
                  context,
                  ref,
                  title: 'Sensibilité pour masquer le menu lors du défilement',
                  options: kMenuHideSensitivityOptions,
                  current: menuHideSensitivity,
                  setter: (v) => ref
                      .read(continuousMenuHideSensitivityProvider.notifier)
                      .set(v),
                ),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Navigation ─────────────────────────────────────────────
              _Section(icon: Broken.routing, label: 'Navigation'),
              _Tile(
                icon: Broken.grid_1,
                title: l10n.navigation_layout,
                value: _navLayoutName(navigationLayout, context),
                onTap: () => _pickNavigationLayout(
                  context,
                  ref,
                  navigationLayout,
                ),
              ),
              if (isMobile)
                SwitchListTile(
                  secondary: const Icon(Broken.volume_high),
                  value: volumeButtonNav,
                  title: const Text('Avec les boutons de volume'),
                  subtitle: const Text(
                    'Utilisez ▲/▼ pour tourner les pages',
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) =>
                      ref.read(volumeButtonNavigationStateProvider.notifier).set(v),
                ),
              if (isMobile && volumeButtonNav)
                SwitchListTile(
                  secondary: const Icon(Broken.arrow_swap_horizontal),
                  value: invertVolumeButtonNav,
                  title: const Text('Inverser les boutons de volume'),
                  subtitle: Text(
                    invertVolumeButtonNav
                        ? '▲ → page suivante  •  ▼ → page précédente'
                        : '▲ → page précédente  •  ▼ → page suivante',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) => ref
                      .read(
                        invertVolumeButtonNavigationStateProvider.notifier,
                      )
                      .set(v),
                ),
              _Tile(
                icon: Broken.element_4,
                title: 'Navigateur de chapitres vertical',
                value: optionLabel(
                  kVerticalNavigatorOptions,
                  verticalNavigator,
                ),
                onTap: () => _pickString(
                  context,
                  ref,
                  title: 'Navigateur de chapitres vertical',
                  options: kVerticalNavigatorOptions,
                  current: verticalNavigator,
                  setter: (v) => ref
                      .read(verticalChapterNavigatorProvider.notifier)
                      .set(v),
                ),
              ),

              const Divider(height: 8, indent: 16, endIndent: 16),

              // ── Actions ────────────────────────────────────────────────
              _Section(icon: Broken.flash, label: 'Actions'),
              SwitchListTile(
                secondary: const Icon(Broken.mouse_square),
                value: longPressActions,
                title: const Text('Afficher les actions en appuyant longuement'),
                onChanged: (v) =>
                    ref.read(longPressActionsProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.folder),
                value: savePagesSeparately,
                title: const Text(
                  'Enregistrer les pages dans des dossiers séparés',
                ),
                onChanged: (v) =>
                    ref.read(savePagesInSeparateFoldersProvider.notifier).set(v),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // ── Pickers ──────────────────────────────────────────────────────────────

  void _pickReaderMode(BuildContext context, WidgetRef ref, ReaderMode current) {
    _radioSheet<ReaderMode>(
      context,
      title: context.l10n.default_reading_mode,
      options: ReaderMode.values,
      current: current,
      labelOf: (m) => getReaderModeName(m, context),
      onPicked: (v) => ref.read(defaultReadingModeStateProvider.notifier).set(v),
    );
  }

  void _pickDoubleTapSpeed(BuildContext context, WidgetRef ref, int current) {
    _radioSheet<int>(
      context,
      title: context.l10n.double_tap_animation_speed,
      options: const [0, 1, 2],
      current: current,
      labelOf: (i) => getDoubleTapAnimationSpeedName(i, context),
      onPicked: (v) =>
          ref.read(doubleTapAnimationSpeedStateProvider.notifier).set(v),
    );
  }

  void _pickBackgroundColor(
    BuildContext context,
    WidgetRef ref,
    BackgroundColor current,
  ) {
    _radioSheet<BackgroundColor>(
      context,
      title: context.l10n.background_color,
      options: BackgroundColor.values,
      current: current,
      labelOf: (c) => getBackgroundColorName(c, context),
      onPicked: (v) => ref.read(backgroundColorStateProvider.notifier).set(v),
    );
  }

  void _pickScaleType(BuildContext context, WidgetRef ref, ScaleType current) {
    final names = getScaleTypeNames(context);
    _radioSheet<int>(
      context,
      title: context.l10n.scale_type,
      options: List.generate(names.length, (i) => i),
      current: current.index,
      labelOf: (i) => names[i],
      onPicked: (v) =>
          ref.read(scaleTypeStateProvider.notifier).set(ScaleType.values[v]),
    );
  }

  void _pickNavigationLayout(BuildContext context, WidgetRef ref, int current) {
    _radioSheet<int>(
      context,
      title: context.l10n.navigation_layout,
      options: List.generate(6, (i) => i),
      current: current,
      labelOf: (i) => _navLayoutName(i, context),
      onPicked: (v) =>
          ref.read(readerNavigationLayoutStateProvider.notifier).set(v),
    );
  }

  void _pickString(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<(String, String)> options,
    required String current,
    required ValueChanged<String> setter,
  }) {
    _radioSheet<String>(
      context,
      title: title,
      options: options.map((e) => e.$1).toList(),
      current: current,
      labelOf: (v) => optionLabel(options, v),
      onPicked: setter,
    );
  }

  void _pickInt(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<(int, String)> options,
    required int current,
    required ValueChanged<int> setter,
  }) {
    _radioSheet<int>(
      context,
      title: title,
      options: options.map((e) => e.$1).toList(),
      current: current,
      labelOf: (v) {
        for (final o in options) {
          if (o.$1 == v) return o.$2;
        }
        return options.first.$2;
      },
      onPicked: setter,
    );
  }
}

// ── Shared widgets ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
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

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.slider,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? slider;

  @override
  Widget build(BuildContext context) {
    if (slider != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            trailing: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: context.secondaryColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: slider,
          ),
        ],
      );
    }
    if (slider != null) {
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: const TextStyle(fontSize: 11)),
        trailing: Text(
          value,
          style: TextStyle(fontSize: 12, color: context.secondaryColor),
        ),
        onTap: onTap,
      );
    }
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle ?? value,
        style: TextStyle(fontSize: 11, color: context.secondaryColor),
      ),
      trailing: const Icon(Broken.arrow_right_2),
      onTap: onTap,
    );
  }
}

/// Bottom-sheet radio picker shared by every reader option.
void _radioSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T current,
  required String Function(T) labelOf,
  required ValueChanged<T> onPicked,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: RadioGroup<T>(
        groupValue: current,
        onChanged: (v) {
          if (v == null) return;
          onPicked(v);
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

// ── Label helpers ────────────────────────────────────────────────────────────

String getReaderModeName(ReaderMode readerMode, BuildContext context) {
  return switch (readerMode) {
    ReaderMode.vertical => context.l10n.reading_mode_vertical,
    ReaderMode.verticalContinuous =>
      context.l10n.reading_mode_vertical_continuous,
    ReaderMode.ltr => context.l10n.reading_mode_left_to_right,
    ReaderMode.rtl => context.l10n.reading_mode_right_to_left,
    ReaderMode.horizontalContinuous =>
      context.l10n.horizontal_continious,
    ReaderMode.horizontalContinuousRTL =>
      "${context.l10n.horizontal_continious} (RTL)",
    _ => context.l10n.reading_mode_webtoon,
  };
}

String getBackgroundColorName(BackgroundColor color, BuildContext context) {
  return switch (color) {
    BackgroundColor.white => context.l10n.white,
    BackgroundColor.grey => context.l10n.grey,
    BackgroundColor.black => context.l10n.black,
    _ => context.l10n.automaic,
  };
}

Color? getBackgroundColor(BackgroundColor backgroundColor) {
  return switch (backgroundColor) {
    BackgroundColor.white => Colors.white,
    BackgroundColor.grey => Colors.grey,
    BackgroundColor.black => Colors.black,
    _ => null,
  };
}

String getDoubleTapAnimationSpeedName(int index, BuildContext context) {
  return switch (index) {
    0 => context.l10n.no_animation,
    1 => context.l10n.normal,
    _ => context.l10n.fast,
  };
}

String getAnimationSpeedName(int type, BuildContext context) =>
    getDoubleTapAnimationSpeedName(type, context);

BlendMode? getColorFilterBlendMode(
  ColorFilterBlendMode mode,
  BuildContext context,
) {
  return switch (mode) {
    ColorFilterBlendMode.none => null,
    ColorFilterBlendMode.multiply => BlendMode.multiply,
    ColorFilterBlendMode.screen => BlendMode.screen,
    ColorFilterBlendMode.overlay => BlendMode.overlay,
    ColorFilterBlendMode.colorDodge => BlendMode.colorDodge,
    ColorFilterBlendMode.lighten => BlendMode.lighten,
    ColorFilterBlendMode.colorBurn => BlendMode.colorBurn,
    ColorFilterBlendMode.difference => BlendMode.difference,
    ColorFilterBlendMode.saturation => BlendMode.saturation,
    ColorFilterBlendMode.softLight => BlendMode.softLight,
    ColorFilterBlendMode.plus => BlendMode.plus,
    ColorFilterBlendMode.exclusion => BlendMode.exclusion,
    _ => BlendMode.darken,
  };
}

String getColorFilterBlendModeName(
  ColorFilterBlendMode mode,
  BuildContext context,
) {
  return switch (mode) {
    ColorFilterBlendMode.none => context.l10n.blend_mode_default,
    ColorFilterBlendMode.multiply => context.l10n.blend_mode_multiply,
    ColorFilterBlendMode.screen => context.l10n.blend_mode_screen,
    ColorFilterBlendMode.overlay => context.l10n.blend_mode_overlay,
    ColorFilterBlendMode.colorDodge => context.l10n.blend_mode_colorDodge,
    ColorFilterBlendMode.lighten => context.l10n.blend_mode_lighten,
    ColorFilterBlendMode.colorBurn => context.l10n.blend_mode_colorBurn,
    ColorFilterBlendMode.difference => context.l10n.blend_mode_difference,
    ColorFilterBlendMode.saturation => context.l10n.blend_mode_saturation,
    ColorFilterBlendMode.softLight => context.l10n.blend_mode_softLight,
    ColorFilterBlendMode.plus => context.l10n.blend_mode_plus,
    ColorFilterBlendMode.exclusion => context.l10n.blend_mode_exclusion,
    _ => context.l10n.blend_mode_darken,
  };
}

List<String> getScaleTypeNames(BuildContext context) => [
  context.l10n.scale_type_fit_screen,
  context.l10n.scale_type_stretch,
  context.l10n.scale_type_fit_width,
  context.l10n.scale_type_fit_height,
];

String _navLayoutName(int index, BuildContext context) {
  return switch (index) {
    0 => context.l10n.nav_layout_default,
    1 => context.l10n.nav_layout_l_shaped,
    2 => context.l10n.nav_layout_kindle,
    3 => context.l10n.nav_layout_edge,
    4 => context.l10n.nav_layout_right_and_left,
    5 => context.l10n.nav_layout_disabled,
    _ => context.l10n.nav_layout_default,
  };
}
