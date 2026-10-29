import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/models/catalog_entry.dart';
import 'package:watchtower/models/catalog_shelf.dart';
import 'package:watchtower/models/catalog_taxonomy.dart';
import 'package:watchtower/modules/browse/marketplace_palette.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// Card geometry shared by every shelf, so two shelves never disagree on how
/// tall a card is and the grid never has to guess.
class CatalogCardMetrics {
  /// Total card height. Chosen so a two-row shelf stays shorter than a phone
  /// viewport and the whole 2 × 2 block is visible without vertical scrolling.
  static const double cardHeight = 152;

  /// Space between two cards, horizontally and vertically.
  static const double gap = 10;

  /// Outer horizontal padding of a shelf, aligned with the rest of the screen.
  static const double padding = 16;

  /// Smallest a card may get before the text inside stops being readable.
  static const double minCardWidth = 140;

  /// Widest a card may get. Past this the shelf widens the number of visible
  /// columns instead of stretching the cards, which is what keeps a tablet
  /// layout from turning into two oversized tiles.
  static const double maxCardWidth = 220;

  /// Card width for a viewport of [availableWidth].
  static double cardWidthFor(double availableWidth) {
    final target = (availableWidth - gap) / 2;
    return target.clamp(minCardWidth, maxCardWidth).toDouble();
  }

  /// Height of a shelf block: two rows plus the gap between them.
  static const double shelfHeight = cardHeight * 2 + gap;
}

/// Visual state of an entry inside the catalogue.
enum CatalogCardStatus { available, installed, update }

/// One catalogue entry, as a compact tile.
///
/// The card is deliberately primitive-only: it takes an [entry] plus the
/// install state as booleans and callbacks, so it can be rendered in a widget
/// test without a provider scope, a network stack, or the Marketplace screen.
class CatalogCard extends StatelessWidget {
  final CatalogEntryView entry;

  /// Pre-computed tags for this entry. Passed in because the shelf builder
  /// already canonicalised them once for the whole catalogue.
  final List<String> tags;

  final CatalogCardStatus status;
  final bool busy;
  final bool isNew;
  final VoidCallback onTap;
  final VoidCallback? onInstall;
  final VoidCallback? onSettings;

  /// Icon URL, already normalised by the caller.
  final String? iconUrl;

  /// Description published by the index, already trimmed by the caller.
  ///
  /// This is the same text the extension's settings page shows, so the card
  /// never invents a summary: when the index has nothing to say the card
  /// simply omits the description line.
  final String description;

  /// Opens the extension's website. Null when the index publishes no base URL,
  /// in which case the redirect affordance is hidden instead of dead.
  final VoidCallback? onOpenSite;

  const CatalogCard({
    super.key,
    required this.entry,
    required this.tags,
    required this.status,
    required this.onTap,
    this.iconUrl,
    this.busy = false,
    this.isNew = false,
    this.onInstall,
    this.onSettings,
    this.description = '',
    this.onOpenSite,
  });

  bool get _featured => tags.contains('featured');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Same source of truth as the rest of the Marketplace, so a light-theme
    // user gets a light card instead of the black tile this used to be.
    final palette = MarketplacePalette.of(context);
    final surface = palette.surface;
    final border = palette.border;
    final text = palette.text;
    final muted = palette.muted;

    return Semantics(
      button: true,
      label: entry.name,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CatalogIcon(
                      name: entry.name,
                      iconUrl: iconUrl,
                      size: 38,
                      tint: scheme.primary,
                    ),
                    const Spacer(),
                    _StatusAction(
                      status: status,
                      busy: busy,
                      onInstall: onInstall,
                      onSettings: onSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _metaLine(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 10.5),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      description.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                _Footer(
                  l10n: l10n,
                  tags: tags,
                  isNew: isNew,
                  featured: _featured,
                  onOpenSite: onOpenSite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Language and catalogue, the two facts every entry has.
  String _metaLine(AppLocalizations l10n) {
    final language = CatalogTaxonomy.filterKnown(entry.tags)
        .where(CatalogTaxonomy.isLanguageTag)
        .map((tag) => CatalogTaxonomy.label(l10n, tag))
        .firstOrNull;
    final type = CatalogTaxonomy.label(
      l10n,
      CatalogTaxonomy.itemTypeToContent[entry.itemType] ?? '',
    );
    return language == null ? type : '$type · $language';
  }
}

/// Bottom row of a card: auto-scrolling tags on the left, the "open website"
/// redirect pinned to the bottom-right corner.
class _Footer extends StatelessWidget {
  final AppLocalizations l10n;
  final List<String> tags;
  final bool isNew;
  final bool featured;
  final VoidCallback? onOpenSite;

  const _Footer({
    required this.l10n,
    required this.tags,
    required this.isNew,
    required this.featured,
    this.onOpenSite,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Expanded(child: _tagStrip(context)),
          if (onOpenSite != null) ...[
            const SizedBox(width: 4),
            _SiteRedirect(l10n: l10n, onTap: onOpenSite!),
          ],
        ],
      ),
    );
  }

  Widget _tagStrip(BuildContext context) {
    if (featured || isNew) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _Badge(
          label: featured ? l10n.catalog_tag_featured : l10n.catalog_tag_new,
          color: featured
              ? MarketplacePalette.of(context).accentCyan
              : MarketplacePalette.of(context).accent,
        ),
      );
    }
    // Content and language tags are already in the meta line, so only the
    // distinguishing tags are worth the space. Two chips is the ceiling: a
    // third starts to crowd the card and push the title out of view.
    final shown = tags
        .where((tag) => !CatalogTaxonomy.isLanguageTag(tag))
        .where((tag) => tag != 'watch' && tag != 'read')
        .take(2)
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return _AutoScrollTags(
      children: [
        for (final tag in shown)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _Badge(
              label: CatalogTaxonomy.label(l10n, tag),
              color: MarketplacePalette.of(context).muted,
              outlined: true,
            ),
          ),
      ],
    );
  }
}

/// A row that drifts left and right on its own when it is wider than the card.
///
/// The strip is a plain horizontal [SingleChildScrollView], so the user can
/// also drag it by hand and the animation simply follows the same offset. When
/// the tags fit there is nothing to scroll and no ticker is started at all,
/// which keeps a shelf of small cards free of idle animations.
class _AutoScrollTags extends StatefulWidget {
  final List<Widget> children;

  const _AutoScrollTags({required this.children});

  @override
  State<_AutoScrollTags> createState() => _AutoScrollTagsState();
}

class _AutoScrollTagsState extends State<_AutoScrollTags>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  AnimationController? _drift;
  double _extent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_sync);
  }

  @override
  void didUpdateWidget(covariant _AutoScrollTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_sync);
  }

  @override
  void dispose() {
    _drift?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _sync(Duration _) {
    if (!mounted || !_scroll.hasClients) return;
    _extent = _scroll.position.maxScrollExtent;
    if (_extent <= 0 || MediaQuery.disableAnimationsOf(context)) {
      _drift?.stop();
      return;
    }
    final duration = Duration(
      milliseconds: (_extent * 26).round().clamp(1400, 12000),
    );
    if (_drift == null) {
      _drift = AnimationController(vsync: this, duration: duration)
        ..addListener(() {
          if (_scroll.hasClients) _scroll.jumpTo(_drift!.value * _extent);
        })
        ..repeat(reverse: true);
    } else if (_drift!.duration != duration) {
      _drift!.duration = duration;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: widget.children),
    );
  }
}

/// Bottom-right redirect to the extension's own website.
class _SiteRedirect extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _SiteRedirect({required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: l10n.catalog_card_open_site,
      child: Semantics(
        button: true,
        label: l10n.catalog_card_open_site,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.open_in_new_rounded, size: 13, color: color),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const _Badge({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Install affordance: the entry's state, and a one-tap install.
///
/// Kept as an icon rather than a full-width button so the card can stay
/// compact; the full labelled action lives on the details sheet, which the
/// card's tap opens.
class _StatusAction extends StatelessWidget {
  final CatalogCardStatus status;
  final bool busy;
  final VoidCallback? onInstall;
  final VoidCallback? onSettings;

  const _StatusAction({
    required this.status,
    required this.busy,
    this.onInstall,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (busy) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: Padding(
          padding: EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final palette = MarketplacePalette.of(context);
    final (icon, color, tooltip) = switch (status) {
      CatalogCardStatus.installed => (
        Broken.tick_circle,
        palette.accent,
        l10n.installed,
      ),
      CatalogCardStatus.update => (
        Icons.refresh_rounded,
        palette.accent,
        l10n.updates,
      ),
      CatalogCardStatus.available => (
        Broken.add_circle,
        palette.accentCyan,
        l10n.install,
      ),
    };
    final action = status == CatalogCardStatus.installed
        ? onSettings
        : onInstall;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: action,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        icon: Icon(icon, color: color, size: 21),
      ),
    );
  }
}

/// Icon with initials fallback, matching the rest of the Marketplace.
///
/// Public so the plugin cards can show a repository-hosted logo with the same
/// fallback behaviour the catalogue cards use, instead of a second, slightly
/// different implementation.
class CatalogIcon extends StatelessWidget {
  final String name;
  final String? iconUrl;
  final double size;
  final Color tint;

  const CatalogIcon({
    super.key,
    required this.name,
    required this.iconUrl,
    required this.size,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final url = iconUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? _fallback(context)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(context),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.substring(0, 1).toUpperCase())
        .join();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint, MarketplacePalette.of(context).surfaceHigh],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          maxLines: 1,
          style: TextStyle(
            color: MarketplacePalette.of(context).onAccent,
            fontSize: size * 0.3,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// A shelf: title, optional "see all", and a 2 × 2 grid that scrolls
/// horizontally.
///
/// Two rows and two columns are visible at a time; the horizontal swipe moves
/// to the next pair of columns. The grid is a real Flutter [GridView], so the
/// horizontal drag and the page's vertical scroll resolve through the normal
/// gesture arena instead of fighting over raw pointer events.
class CatalogShelfGrid extends StatelessWidget {
  final List<CatalogEntryView> entries;
  final Widget Function(BuildContext context, CatalogEntryView entry)
  cardBuilder;

  const CatalogShelfGrid({
    super.key,
    required this.entries,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = CatalogCardMetrics.cardWidthFor(
          width - CatalogCardMetrics.padding * 2,
        );
        // Card width is capped, so a phone shows exactly two columns and a
        // tablet shows the same card at the same size with more of them in
        // view, instead of two oversized tiles.
        return SizedBox(
          height: CatalogCardMetrics.shelfHeight,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: CatalogCardMetrics.padding,
            ),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: CatalogCardMetrics.gap,
              crossAxisSpacing: CatalogCardMetrics.gap,
              mainAxisExtent: cardWidth,
            ),
            itemCount: entries.length,
            addAutomaticKeepAlives: false,
            itemBuilder: (context, index) =>
                cardBuilder(context, entries[index]),
          ),
        );
      },
    );
  }
}

/// Header shared by every shelf: title, optional ordering note, count, and the
/// "see all" action.
class CatalogShelfHeader extends StatelessWidget {
  final CatalogShelfSpec spec;
  final int count;
  final VoidCallback? onSeeAll;

  const CatalogShelfHeader({
    super.key,
    required this.spec,
    required this.count,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = spec.orderNote(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MarketplacePalette.of(context).text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MarketplacePalette.of(context).muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.catalog_see_all,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 17),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Placeholder shown while a shelf's catalogue is still loading.
class CatalogShelfSkeleton extends StatelessWidget {
  const CatalogShelfSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = MarketplacePalette.of(context).surfaceHigh;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = CatalogCardMetrics.cardWidthFor(
          constraints.maxWidth - CatalogCardMetrics.padding * 2,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            CatalogCardMetrics.padding,
            0,
            CatalogCardMetrics.padding,
            0,
          ),
          child: SizedBox(
            height: CatalogCardMetrics.shelfHeight,
            child: Row(
              children: [
                for (var column = 0; column < 2; column++) ...[
                  SizedBox(
                    width: cardWidth,
                    child: Column(
                      children: [
                        for (var row = 0; row < 2; row++) ...[
                          Container(
                            height: CatalogCardMetrics.cardHeight,
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          if (row == 0)
                            const SizedBox(height: CatalogCardMetrics.gap),
                        ],
                      ],
                    ),
                  ),
                  if (column == 0)
                    const SizedBox(width: CatalogCardMetrics.gap),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
