import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/utils/open_marketplace.dart';

/// Shown when no metadata provider is installed/selected yet.
///
/// Default selection is automatic at install time, so this screen only needs
/// to guide the user to the marketplace — no manual override controls.
class NoDefaultMetadataPlugin extends ConsumerWidget {
  const NoDefaultMetadataPlugin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: Icons.extension_outlined,
      title: context.l10n.no_default_metadata_provider_selected,
      message: context.l10n.manage_metadata_providers,
      actionLabel: context.l10n.manage_metadata_providers,
      onAction: () => openMarketplace(context),
    );
  }
}
