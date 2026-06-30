import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/pages/search/search.dart';

class SearchPlaceholder extends HookConsumerWidget {
  final AsyncValue snapshot;
  final Widget child;
  const SearchPlaceholder({
    super.key,
    required this.child,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.sizeOf(context);

    final searchTerm = ref.watch(searchTermStateProvider);

    return switch ((searchTerm.isEmpty, snapshot.isLoading)) {
      (true, false) => Column(
          children: [
            SizedBox(
              height: mediaQuery.height * 0.2,
            ),
            Undraw(
              illustration: UndrawIllustration.explore,
              color: theme.colorScheme.primary,
              height: 200,
            ),
            const SizedBox(height: 20),
            Text(context.l10n.search_to_get_results),
          ],
        ),
      (false, true) => Container(
          constraints: BoxConstraints(
            maxWidth:
                mediaQuery.lgAndUp ? mediaQuery.width * 0.5 : mediaQuery.width,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                context.l10n.crunching_results,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      _ => child,
    };
  }
}
