import 'package:auto_route/auto_route.dart';
    import 'package:flutter/material.dart' as mat;
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:flutter/material.dart';
    import 'package:watchtower/modules/music/collections/routes.gr.dart';
    import 'package:watchtower/modules/music/extensions/context.dart';
    import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';

    class AnonymousFallback extends ConsumerWidget {
    final Widget? child;
    const AnonymousFallback({super.key, this.child});

    @override
    Widget build(BuildContext context, ref) {
      final isLoggedIn = ref.watch(metadataPluginAuthenticatedProvider);
      if (isLoggedIn.isLoading) return const Center(child: mat.CircularProgressIndicator());
      if (isLoggedIn.asData?.value == true && child != null) return child!;
      final primaryColor = Theme.of(context).colorScheme.primary;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            mat.Icon(mat.Icons.lock_outline_rounded, size: 80, color: primaryColor),
            Text(context.l10n.not_logged_in),
            FilledButton(
              child: Text(context.l10n.login),
              onPressed: () => context.pushRoute(const SettingsMetadataProviderRoute()),
            ),
          ],
        ),
      );
    }
    }
    