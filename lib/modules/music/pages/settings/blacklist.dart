import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/provider/blacklist_provider.dart';

class BlackListPage extends HookConsumerWidget {
  static const name = "blacklist";

  const BlackListPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final blacklist = ref.watch(blacklistProvider);
    final searchText = useState("");

    final items = useMemoized(() {
      final all = blacklist.asData?.value ?? const <BlacklistTableData>[];
      if (searchText.value.isEmpty) return all;
      return all
          .map(
            (e) => (
              weightedRatio(
                "${e.name} ${e.elementType.name}",
                searchText.value,
              ),
              e,
            ),
          )
          .where((e) => e.$1 > 50)
          .sorted((a, b) => b.$1.compareTo(a.$1))
          .map((e) => e.$2)
          .toList();
    }, [blacklist, searchText.value]);

    final cs = Theme.of(context).colorScheme;

    return SettingsSubpageScaffold(
      title: context.l10n.blacklist,
      searchHint: context.l10n.search,
      onSearchChanged: (value) => searchText.value = value,
      leading: const MusicBackButton(),
      slivers: [
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Broken.forbidden_2,
                      size: 42,
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.nothing_found,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  item.elementType == BlacklistedType.artist
                      ? Broken.profile_2user
                      : Broken.musicnote,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(switch (item.elementType) {
                  BlacklistedType.artist => context.l10n.artist,
                  BlacklistedType.track => context.l10n.track,
                }, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                trailing: IconButton(
                  icon: Icon(Broken.trash, size: 18, color: cs.error),
                  tooltip: context.l10n.delete,
                  onPressed: () => ref
                      .read(blacklistProvider.notifier)
                      .remove(item.elementId),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
  }
}
