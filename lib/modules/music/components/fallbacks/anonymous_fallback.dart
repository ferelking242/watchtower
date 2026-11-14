import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';

/// Gate shown when a signed-in metadata provider is required but the user is
/// anonymous. Uses the shared empty-state component for a native look.
class AnonymousFallback extends ConsumerWidget {
  final Widget? child;
  const AnonymousFallback({super.key, this.child});

  @override
  Widget build(BuildContext context, ref) {
    final isLoggedIn = ref.watch(metadataPluginAuthenticatedProvider);
    if (isLoggedIn.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (isLoggedIn.asData?.value == true && child != null) return child!;
    return AppEmptyState(
      icon: Icons.lock_outline_rounded,
      title: context.l10n.not_logged_in,
      message: context.l10n.login_to_your_music_account,
      actionLabel: context.l10n.login,
      onAction: () =>
          context.pushRoute(const SettingsMetadataProviderRoute()),
    );
  }
}
