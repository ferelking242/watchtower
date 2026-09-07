import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/browse/extension/widgets/extension_lang_list_tile_widget.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';

class ExtensionsLang extends ConsumerWidget {
  final ItemType itemType;
  const ExtensionsLang({required this.itemType, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.extensions),
        actions: [
          ArrowPopupMenuButton(
            popUpAnimationStyle: popupAnimationStyle,
            itemBuilder: (context) {
              return [
                PopupMenuItem<int>(value: 0, child: Text(l10n.enable_all)),
                PopupMenuItem<int>(value: 1, child: Text(l10n.disable_all)),
              ];
            },
            onSelected: (value) {
              isar.writeTxnSync(() {
                bool enable = true;
                if (value == 0) {
                } else if (value == 1) {
                  enable = false;
                }
                final sources = isar.sources
                    .filter()
                    .idIsNotNull()
                    .and()
                    .itemTypeEqualTo(itemType)
                    .findAllSync();
                for (var source in sources) {
                  isar.sources.putSync(
                    source
                      ..isActive = enable
                      ..updatedAt = DateTime.now().millisecondsSinceEpoch,
                  );
                }
              });
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: isar.sources
            .filter()
            .idIsNotNull()
            .and()
            .itemTypeEqualTo(itemType)
            .watch(fireImmediately: true),
        builder: (context, snapshot) {
          List<Source>? entries = snapshot.hasData ? snapshot.data : [];
          final languages = entries!.map((e) => e.lang!).toSet().toList();

          languages.sort((a, b) => a.compareTo(b));
          return SuperListView.builder(
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final lang = languages[index];
              return ExtensionLangListTileWidget(
                lang: lang,
                onLongPress: () {
                  // Long-press = solo this language: disable every source
                  // whose lang differs and enable every source matching it.
                  // If we are already in that exclusive state, re-enable all
                  // languages so the user can quickly toggle back.
                  final lowerLang = lang.toLowerCase();
                  final otherActive = entries.any(
                    (e) =>
                        e.lang!.toLowerCase() != lowerLang &&
                        (e.isActive ?? false),
                  );
                  final thisActive = entries.any(
                    (e) =>
                        e.lang!.toLowerCase() == lowerLang &&
                        (e.isActive ?? false),
                  );
                  final isolate = otherActive || !thisActive;
                  isar.writeTxnSync(() {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    for (var source in entries) {
                      final matches =
                          source.lang!.toLowerCase() == lowerLang;
                      isar.sources.putSync(
                        source
                          ..isActive = isolate ? matches : true
                          ..updatedAt = now,
                      );
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(
                        isolate
                            ? 'Seules les sources ${lang.toUpperCase()} sont actives'
                            : 'Toutes les langues sont actives',
                      ),
                    ),
                  );
                },
                onChanged: (val) {
                  isar.writeTxnSync(() {
                    for (var source in entries) {
                      if (source.lang!.toLowerCase() == lang.toLowerCase()) {
                        isar.sources.putSync(
                          source
                            ..isActive = val
                            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
                        );
                      }
                    }
                  });
                },
                value: entries
                    .where(
                      (element) =>
                          element.lang!.toLowerCase() == lang.toLowerCase() &&
                          element.isActive!,
                    )
                    .isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}
