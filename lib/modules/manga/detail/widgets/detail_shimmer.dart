import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:watchtower/modules/plugin/nfile/core/icon_fonts/broken_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer building blocks used by the manga/anime detail screen.
//
// The goal is a *detailed* skeleton: the real layout is drawn with grey blocks
// that sweep with a light gradient until the real data/image arrives, instead
// of a flat pulsing rectangle. Sizes and spacings intentionally mirror the
// real widgets (see `_bodyContainer`, `_coverCard`, `ReadMoreWidget` and
// `_DetailTabs`) so the skeleton sits exactly where the content will appear
// and nothing jumps when it is swapped in.
// ─────────────────────────────────────────────────────────────────────────────

/// Real-layout metrics shared by the skeletons and documented next to the
/// widgets they imitate. Keep in sync with:
///  * cover card  → `MangaDetailView._coverCard` (65 × 1.5 by 65 × 2.3)
///  * cover pad   → `_coverCard` Padding(horizontal: 13, vertical: 20)
///  * action row  → `_actionFavouriteAndWebview` ElevatedButtons
///                  (icon 20, gap 4, label fontSize 11)
///  * description → `ReadMoreWidget` (Padding all 8 + horizontal 6, maxLines 3)
///  * tabs        → `_DetailTabs` TabBar (height 44, icon 15, gap 6, label 13)
class DetailSkeletonMetrics {
  DetailSkeletonMetrics._();

  static const double coverWidth = 65 * 1.5; // 97.5
  static const double coverHeight = 65 * 2.3; // 149.5
  static const double coverRadius = 5;
  static const EdgeInsets coverPadding = EdgeInsets.symmetric(
    horizontal: 13,
    vertical: 20,
  );

  static const double actionIconSize = 20;
  static const double actionLabelHeight = 12;
  static const double actionGap = 4;

  static const double descriptionLineHeight = 13;
  static const double descriptionLineGap = 7;

  static const double tabHeight = 44;
  static const double tabIconSize = 15;
  static const double tabGap = 6;
  static const double tabLabelHeight = 12;
}

class DetailShimmer {
  DetailShimmer._();

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color baseColor(BuildContext context) => isLight(context)
      ? const Color(0xFFE1E4EA)
      : const Color(0xFF23232B);

  static Color highlightColor(BuildContext context) => isLight(context)
      ? const Color(0xFFF7F8FB)
      : const Color(0xFF37373F);
}

/// A single shimmering block (text line, chip, cover placeholder…).
class DetailShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final Widget? child;

  const DetailShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: DetailShimmer.baseColor(context),
      highlightColor: DetailShimmer.highlightColor(context),
      period: const Duration(milliseconds: 1300),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        alignment: child == null ? null : Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

/// Detailed skeleton of the hero band that sits behind the manga detail body
/// (the full-width cover/backdrop image is 300 px tall).
///
/// Only the top of that band is really visible — the body stacks an opaque
/// gradient over it below roughly 90 px — so the skeleton reproduces exactly
/// the part that shows through: the cover card and the title / author / status
/// column, at the same coordinates as `MangaDetailView._bodyContainer`.
class DetailHeroShimmer extends StatelessWidget {
  final double height;

  const DetailHeroShimmer({super.key, this.height = 300});

  @override
  Widget build(BuildContext context) {
    // Le contenu réel de la page commence sous la barre de statut (SafeArea
    // du Scaffold) : on décale le squelette d'autant pour que la cover du
    // shimmer coïncide avec la vraie cover dessinée par-dessus.
    final topInset = MediaQuery.paddingOf(context).top;
    return Shimmer.fromColors(
      baseColor: DetailShimmer.baseColor(context),
      highlightColor: DetailShimmer.highlightColor(context),
      period: const Duration(milliseconds: 1300),
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          // Colonne `min` : la rangée garde la hauteur intrinsèque du vrai
          // bloc cover + titres et reste collée en haut de la bande, sinon la
          // cover serait centrée 40 px plus bas que la vraie.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: DetailSkeletonMetrics.coverPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Cover : mêmes cotes et même rayon que `_coverCard`.
                    Container(
                      width: DetailSkeletonMetrics.coverWidth,
                      height: DetailSkeletonMetrics.coverHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          DetailSkeletonMetrics.coverRadius,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Titre + auteur + statut, centrés verticalement comme la
                    // colonne `_titles()` (titre puis `titleDescription`).
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 24,
                            width: double.infinity,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 24,
                            width: 150,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 12,
                            width: 120,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 175,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenu shimmer d'un bouton d'action (icône 20 px + libellé 11 px) à
/// insérer dans les VRAIS `ElevatedButton` de la rangée d'actions : le chrome,
/// les marges internes et la position du bouton restent ceux du bouton
/// chargé — seuls ses contenus scintillent.
class DetailActionButtonSkeleton extends StatelessWidget {
  /// Largeur du bloc de libellé, choisie pour correspondre au texte réel
  /// (« In library », « 3 jours », « Tracking », « Webview »…).
  final double labelWidth;

  const DetailActionButtonSkeleton({super.key, this.labelWidth = 46});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DetailShimmerBox(
          width: DetailSkeletonMetrics.actionIconSize,
          height: DetailSkeletonMetrics.actionIconSize,
          radius: 6,
        ),
        const SizedBox(height: DetailSkeletonMetrics.actionGap),
        DetailShimmerBox(
          width: labelWidth,
          height: DetailSkeletonMetrics.actionLabelHeight,
          radius: 3,
        ),
      ],
    );
  }
}

/// Squelette de la description : trois lignes (le vrai texte utilise
/// `maxLines: 3`) puis le chevron « voir plus », aux mêmes marges que
/// `ReadMoreWidget` (Padding horizontal 6 dans le Padding(all: 8) appelant).
class DetailDescriptionSkeleton extends StatelessWidget {
  const DetailDescriptionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailShimmerBox(
            width: double.infinity,
            height: DetailSkeletonMetrics.descriptionLineHeight,
            radius: 4,
          ),
          const SizedBox(height: DetailSkeletonMetrics.descriptionLineGap),
          const DetailShimmerBox(
            width: double.infinity,
            height: DetailSkeletonMetrics.descriptionLineHeight,
            radius: 4,
          ),
          const SizedBox(height: DetailSkeletonMetrics.descriptionLineGap),
          // Dernière ligne plus courte + chevron, comme le vrai texte tronqué.
          Row(
            children: [
              const Expanded(
                child: DetailShimmerBox(
                  height: DetailSkeletonMetrics.descriptionLineHeight,
                  radius: 4,
                ),
              ),
              const SizedBox(width: 8),
              const DetailShimmerBox(width: 18, height: 18, radius: 5),
            ],
          ),
        ],
      ),
    );
  }
}

/// Image with a detailed shimmer placeholder while it loads.
///
/// Works with any [ImageProvider] (network, memory, extended network …),
/// fades the image in once decoded and falls back to a placeholder on error.
class DetailShimmerImage extends StatelessWidget {
  final ImageProvider? imageProvider;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext context)? placeholderBuilder;
  final Widget Function(BuildContext context)? errorBuilder;

  /// Optional wrapper applied to the decoded image only (for example an
  /// overlay/scrim). The placeholder is rendered on its own so the skeleton
  /// is never dimmed by that overlay.
  final Widget Function(BuildContext context, Widget image)? loadedBuilder;
  final Duration fadeDuration;

  const DetailShimmerImage({
    super.key,
    required this.imageProvider,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholderBuilder,
    this.errorBuilder,
    this.loadedBuilder,
    this.fadeDuration = const Duration(milliseconds: 320),
  });

  @override
  Widget build(BuildContext context) {
    final provider = imageProvider;
    final placeholder =
        placeholderBuilder?.call(context) ??
        DetailShimmerBox(width: width, height: height, radius: 6);

    Widget content;
    if (provider == null) {
      content = placeholder;
    } else {
      content = Image(
        image: provider,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final loaded = loadedBuilder?.call(context, child) ?? child;
          if (wasSynchronouslyLoaded) return loaded;
          return AnimatedSwitcher(
            duration: fadeDuration,
            child: frame != null
                ? KeyedSubtree(key: const ValueKey('image'), child: loaded)
                : KeyedSubtree(
                    key: const ValueKey('placeholder'),
                    child: placeholder,
                  ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            errorBuilder?.call(context) ??
            Container(
              width: width,
              height: height,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Broken.image,
                size: 28,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
      );
    }

    if (borderRadius == null) return content;
    return ClipRRect(borderRadius: borderRadius!, child: content);
  }
}
