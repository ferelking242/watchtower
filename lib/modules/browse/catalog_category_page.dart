import 'package:flutter/material.dart';
import 'package:watchtower/models/catalog_entry.dart';
import 'package:watchtower/models/catalog_shelf.dart';
import 'package:watchtower/modules/browse/catalog_widgets.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// Full grid of everything a shelf matched.
///
/// Opened by the "see all" action of a shelf. It takes the already-resolved
/// entries instead of re-deriving them, so the list the user tapped is exactly
/// the list they get — no second filtering pass that could disagree with the
/// shelf it came from.
class CatalogCategoryPage extends StatelessWidget {
  final CatalogShelfSpec spec;
  final List<CatalogEntryView> entries;
  final Widget Function(BuildContext context, CatalogEntryView entry)
  cardBuilder;

  const CatalogCategoryPage({
    super.key,
    required this.spec,
    required this.entries,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = MarketplacePalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        title: Text(spec.title(l10n)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                l10n.catalog_shelf_count(entries.length),
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.catalog_shelf_empty,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Same card width rule as the shelves, so a card does not
                // change size when the user drills into the full list.
                final columns = (constraints.maxWidth / 200).floor().clamp(
                  2,
                  6,
                );
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: CatalogCardMetrics.gap,
                    crossAxisSpacing: CatalogCardMetrics.gap,
                    mainAxisExtent: CatalogCardMetrics.cardHeight,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) =>
                      cardBuilder(context, entries[index]),
                );
              },
            ),
    );
  }
}
