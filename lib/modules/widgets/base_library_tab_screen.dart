import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/item_type_filters.dart';
import 'package:watchtower/utils/item_type_localization.dart';

abstract class BaseLibraryTabScreenState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T>
    with TickerProviderStateMixin {
  final textEditingController = TextEditingController();
  late TabController tabController;
  late List<ItemType> visibleTabTypes;
  late final List<String> hideItems;
  bool isSearch = false;

  /// Screen-specific title
  String get title;

  /// Icon shown to the left of the title. Screens override this to match the
  /// content they present.
  IconData get titleIcon => Broken.document_text;

  /// Build the content of each tab
  Widget buildTab(ItemType type);

  /// Optional extra actions (refresh, delete, etc.)
  List<Widget> buildExtraActions(BuildContext context) => [];

  /// Optional custom Tab widget (Updates needs this)
  Widget buildTabLabel(ItemType type, String label) {
    return Tab(text: label);
  }

  @override
  void initState() {
    super.initState();
    hideItems = ref.read(hideItemsStateProvider);

    visibleTabTypes = hiddenItemTypes(hideItems);

    tabController = TabController(length: visibleTabTypes.length, vsync: this);

    tabController.addListener(() {
      setState(() {
        textEditingController.clear();
        isSearch = false;
      });
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  ItemType getCurrentItemType() => visibleTabTypes[tabController.index];

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        // The search field must fill the title slot rather than sit inside
        // `actions`: in `actions` the row is min-size, so the field had no
        // bounded width and collapsed into the grey square. Here the title
        // slot gives it a definite width, and `actions` keeps the small
        // search toggle and the page-specific buttons.
        title: isSearch
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SeachFormTextField(
                  controller: textEditingController,
                  onChanged: (_) => setState(() {}),
                  onSuffixPressed: () {
                    textEditingController.clear();
                    setState(() {});
                  },
                  onPressed: () {
                    setState(() => isSearch = false);
                    textEditingController.clear();
                  },
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(titleIcon, size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          if (!isSearch)
            IconButton(
              splashRadius: 20,
              iconSize: 20,
              onPressed: () => setState(() => isSearch = true),
              icon: const Icon(Broken.search_normal_1),
            ),
          ...buildExtraActions(context),
        ],
        bottom: TabBar(
          controller: tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: visibleTabTypes.map((type) {
            return buildTabLabel(type, type.localized(l10n));
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: visibleTabTypes.map(buildTab).toList(),
      ),
    );
  }
}
