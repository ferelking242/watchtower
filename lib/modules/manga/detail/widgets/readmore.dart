import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import 'package:watchtower/modules/manga/detail/widgets/expandable_text.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/display_prefs_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// Description text with a read-more clamp.
///
/// Some sources ship HTML descriptions with `<img>` tags. When the user turns
/// on “Rendre les images dans les descriptions de mangas”, those tags are
/// rendered as real images (and the surrounding markup is honoured) instead of
/// being shown as raw angle brackets.
class ReadMoreWidget extends ConsumerStatefulWidget {
  const ReadMoreWidget({
    super.key,
    required this.text,
    required this.onChanged,
    this.initExpanded = false,
  });
  final Function(bool) onChanged;
  final String text;
  final bool initExpanded;

  @override
  ReadMoreWidgetState createState() => ReadMoreWidgetState();
}

class ReadMoreWidgetState extends ConsumerState<ReadMoreWidget>
    with TickerProviderStateMixin {
  late bool expanded = widget.initExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final renderImages = ref.watch(renderDescriptionImagesProvider);
    final text = widget.text.trim();

    if (widget.text.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text(l10n.no_description)],
      );
    }

    // Only take the HTML path when the toggle is on *and* the source actually
    // sent markup: plain descriptions keep the lighter ExpandableText path.
    if (renderImages && _looksLikeHtml(text)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _HtmlDescription(
          html: text,
          expanded: expanded,
          onToggle: () {
            setState(() => expanded = !expanded);
            widget.onChanged(expanded);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ExpandableText(
        text,
        expandText: '',
        maxLines: 3,
        expanded: expanded,
        linkColor: Colors.transparent,
        animation: true,
        animationDuration: const Duration(milliseconds: 500),
        expandOnTextTap: true,
        collapseOnTextTap: true,
        prefixText: '',
        showGradientOverlay: true,
        gradientOverlayHeight: 30,
        showExpandCollapseIcon: true,
        expandIcon: Icons.keyboard_arrow_down_sharp,
        collapseIcon: Icons.keyboard_arrow_up_sharp,
        onExpandedChanged: (value) {
          setState(() => expanded = value);
          widget.onChanged(value);
        },
      ),
    );
  }
}

/// Cheap markup sniff so plain-text descriptions never pay for an HTML build.
bool _looksLikeHtml(String value) =>
    RegExp(r'<(img|p|br|div|span|a|b|i|u|em|strong)\b', caseSensitive: false)
        .hasMatch(value);

/// Clamped HTML description: the first [collapsedMaxHeight] pixels are shown
/// with a tap-to-expand affordance, mirroring the plain-text read-more.
class _HtmlDescription extends StatefulWidget {
  const _HtmlDescription({
    required this.html,
    required this.expanded,
    required this.onToggle,
  });

  final String html;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<_HtmlDescription> createState() => _HtmlDescriptionState();
}

class _HtmlDescriptionState extends State<_HtmlDescription> {
  static const double collapsedMaxHeight = 96;

  @override
  Widget build(BuildContext context) {
    final body = HtmlWidget(
      widget.html,
      textStyle: DefaultTextStyle.of(context).style,
      onTapUrl: (url) async => false,
    );

    if (widget.expanded) return body;

    return GestureDetector(
      onTap: widget.onToggle,
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: collapsedMaxHeight,
            ),
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: double.infinity,
              child: body,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 30,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor.withValues(
                      alpha: 0,
                    ),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: const Icon(Icons.keyboard_arrow_down_sharp, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
