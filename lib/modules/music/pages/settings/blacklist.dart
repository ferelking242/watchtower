import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:collection/collection.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/components/ui/button_tile.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/blacklist_provider.dart';

class BlackListPage extends HookConsumerWidget {
  static const name = "blacklist";

  const BlackListPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final controller = useScrollController();
    final blacklist = ref.watch(blacklistProvider);
    final searchText = useState("");

    final filteredBlacklist = useMemoized(
      () {
        if (searchText.value.isEmpty) {
          return blacklist.asData?.value ?? [];
        }
        return blacklist.asData?.value
                ?.map(
                  (e) => (
                    weightedRatio(
                        "${e.name} ${e.elementType.name}", searchText.value),
                    e,
                  ),
                )
                .sorted((a, b) => b.$1.compareTo(a.$1))
                .where((e) => e.$1 > 50)
                .map((e) => e.$2)
                .toList() ??
            [];
      },
      [blacklist, searchText.value],
    );

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          leading: MusicBackButton(),
          title: Text(context.l10n.blacklist),
        ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (value) => searchText.value = value,
                decoration: InputDecoration(
                  hintText: context.l10n.search,
                  prefixIcon: const Icon(SpotubeIcons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: InterScrollbar(
                controller: controller,
                child: ListView.builder(
                  controller: controller,
                  shrinkWrap: true,
                  itemCount: filteredBlacklist.length,
                  itemBuilder: (context, index) {
                    final item = filteredBlacklist.elementAt(index);
                    return ButtonTile(
                      leading: Text("${index + 1}."),
                      title: Text("${item.name} (${item.elementType.name})"),
                      trailing: IconButton(
                        icon: Icon(SpotubeIcons.trash,
                            color: Colors.red[400]),
                        onPressed: () {
                          ref
                              .read(blacklistProvider.notifier)
                              .remove(item.elementId);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
