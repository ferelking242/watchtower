import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_search_index.dart';

/// Collapsing header shared by every settings sub-page.
///
/// The page title lives on the page; as the user scrolls it slides up into a
/// pinned compact header that keeps the broken back chevron and the broken
/// search icon reachable — the same behaviour as the Mihon settings sub-pages.
class SettingsSubpageScaffold extends StatelessWidget {
  const SettingsSubpageScaffold({
    super.key,
    required this.title,
    this.slivers = const [],
    this.body,
    this.trailing,
    this.bottom,
    this.floatingActionButton,
    this.expandedHeight = 116,
  }) : assert(
         slivers.length > 0 || body != null,
         'Provide either slivers or a body',
       );

  final String title;
  final List<Widget> slivers;

  /// Alternative to [slivers] for screens that bring their own scrollable
  /// (for example a `ReorderableListView`). Rendered as a filling sliver so the
  /// collapsing header still works.
  final Widget? body;
  final Widget? trailing;

  /// Pinned below the collapsed header, for pages that need tabs.
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            expandedHeight: expandedHeight,
            bottom: bottom,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Broken.arrow_left_2),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Broken.search_normal),
                tooltip: 'Rechercher',
                onPressed: () => showSettingsSearchSheet(context),
              ),
              ?trailing,
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 14,
                end: 96,
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (body != null)
            SliverFillRemaining(hasScrollBody: true, child: body!)
          else
            ...slivers,
        ],
      ),
    );
  }
}

/// Opens the settings search as a bottom sheet and navigates to the chosen
/// entry. Results span every settings page, not just the one that is open.
Future<void> showSettingsSearchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _SettingsSearchSheet(),
  );
}

class _SettingsSearchSheet extends StatefulWidget {
  const _SettingsSearchSheet();

  @override
  State<_SettingsSearchSheet> createState() => _SettingsSearchSheetState();
}

class _SettingsSearchSheetState extends State<_SettingsSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _query = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final results = searchSettings(_query);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher dans les paramètres…',
                  prefixIcon: const Icon(Broken.search_normal, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Broken.close_circle, size: 20),
                          onPressed: () => _controller.clear(),
                        ),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Broken.search_normal,
                            size: 42,
                            color: cs.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun résultat pour « $_query »',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return ListTile(
                          leading: Icon(Broken.setting_2, color: cs.primary),
                          title: Text(entry.title),
                          subtitle: Text(
                            entry.page,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push(entry.route);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
