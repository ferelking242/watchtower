import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/ui_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class UiSettingsScreen extends ConsumerWidget {
  const UiSettingsScreen({super.key});

  void _showCarouselStyleDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(carouselStyleProvider);
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.appearance_ui_carousel_style),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              kCarouselStyles.length,
              (i) => RadioGroup<int>(
                groupValue: current,
                onChanged: (v) {
                  if (v != null) {
                    ref.read(carouselStyleProvider.notifier).set(v);
                  }
                  Navigator.pop(context);
                },
                child: RadioListTile<int>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: i,
                  title: Text(carouselStyleLabel(l10n, i)),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: context.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final carouselStyle = ref.watch(carouselStyleProvider);
    final showSynopsis = ref.watch(carouselSynopsisProvider);
    final glowEffects = ref.watch(glowEffectsProvider);
    final fallingPetals = ref.watch(fallingPetalsProvider);
    final kenBurns = ref.watch(kenBurnsProvider);
    final pageTransStyle = ref.watch(pageTransitionStyleProvider);
    final headerBlur = ref.watch(headerBlurProvider);
    final bottomSheetBlur = ref.watch(bottomSheetBlurProvider);
    final blurIntensity = ref.watch(blurIntensityProvider);

    Widget iconBox(IconData icon) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: cs.primary, size: 20),
    );

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );

    final l10n = context.l10n;
    return SettingsSubpageScaffold(
      title: l10n.appearance_ui_title,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel(l10n.appearance_ui_section_ui),
              ListTile(
                leading: iconBox(Broken.slider_horizontal),
                title: Text(l10n.appearance_ui_carousel_style),
                subtitle: Text(
                  carouselStyleLabel(l10n, carouselStyle),
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _showCarouselStyleDialog(context, ref),
              ),
              SwitchListTile(
                secondary: iconBox(Broken.document_text),
                title: Text(l10n.appearance_ui_carousel_synopsis),
                subtitle: Text(
                  l10n.appearance_ui_carousel_synopsis_subtitle,
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                value: showSynopsis,
                onChanged: (v) =>
                    ref.read(carouselSynopsisProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: iconBox(Broken.magic_star),
                title: Text(l10n.appearance_ui_glow),
                subtitle: Text(
                  l10n.appearance_ui_glow_subtitle,
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                value: glowEffects,
                onChanged: (v) => ref.read(glowEffectsProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: iconBox(Broken.flash),
                title: Text(l10n.appearance_ui_animated_bg),
                subtitle: Text(
                  l10n.appearance_ui_animated_bg_subtitle,
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                value: kenBurns,
                onChanged: (v) => ref.read(kenBurnsProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: iconBox(Broken.brush_2),
                title: Text(l10n.appearance_ui_petals),
                subtitle: Text(
                  l10n.appearance_ui_petals_subtitle,
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                value: fallingPetals,
                onChanged: (v) =>
                    ref.read(fallingPetalsProvider.notifier).set(v),
              ),
              const Divider(height: 24),
              sectionLabel(l10n.appearance_ui_section_blur),
              SwitchListTile(
                secondary: iconBox(Broken.blur),
                title: Text(l10n.appearance_ui_frosted_header),
                subtitle: Text(
                  l10n.appearance_ui_frosted_header_subtitle,
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                value: headerBlur,
                onChanged: (v) => ref.read(headerBlurProvider.notifier).set(v),
              ),
              SwitchListTile(
                secondary: iconBox(Broken.layer),
                title: Text(l10n.appearance_ui_frosted_sheets),
                subtitle: Text(
                  l10n.appearance_ui_frosted_sheets_subtitle,
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                value: bottomSheetBlur,
                onChanged: (v) =>
                    ref.read(bottomSheetBlurProvider.notifier).set(v),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        iconBox(Broken.setting_4),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.appearance_ui_blur_intensity,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${(blurIntensity * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: blurIntensity,
                      min: 0.2,
                      max: 2.0,
                      divisions: 18,
                      onChanged: (v) =>
                          ref.read(blurIntensityProvider.notifier).set(v),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              sectionLabel(l10n.appearance_ui_section_transitions),
              ListTile(
                leading: iconBox(Broken.arrow_swap),
                title: Text(l10n.appearance_ui_transition_style),
                subtitle: Text(
                  pageTransitionStyleLabel(l10n, pageTransStyle),
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => _showPageTransitionDialog(context, ref),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  void _showPageTransitionDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(pageTransitionStyleProvider);
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.appearance_ui_transition_style),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              kPageTransitionStyles.length,
              (i) => RadioGroup<int>(
                groupValue: current,
                onChanged: (v) {
                  if (v != null) {
                    ref.read(pageTransitionStyleProvider.notifier).set(v);
                  }
                  Navigator.pop(context);
                },
                child: RadioListTile<int>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: i,
                  title: Text(pageTransitionStyleLabel(l10n, i)),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: context.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
