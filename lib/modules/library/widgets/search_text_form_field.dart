import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/providers/l10n_providers.dart';

/// Redesigned animated search field used inside [LibraryAppBar].
///
/// Changes vs old version:
/// - [StatefulWidget] with [FocusNode] for focus animation (border glow + color).
/// - Broken icons: [Broken.arrow_left_2] back, [Broken.close_circle] clear,
///   [Broken.slider_horizontal] filter (optional).
/// - Better theme integration, rounded corners, improved padding.
/// - Optional [filterButton] widget shown at the right end (filter overlay trigger).
class SeachFormTextField extends StatefulWidget {
  final Function(String)? onChanged;
  final VoidCallback onPressed;
  final VoidCallback onSuffixPressed;
  final TextEditingController controller;
  final Function(String)? onFieldSubmitted;
  final bool autofocus;

  /// Optional widget shown at the right of the field (e.g. [AdaptiveOverlayMenuButton]).
  /// When null no filter icon is shown.
  final Widget? filterButton;

  const SeachFormTextField({
    super.key,
    required this.onChanged,
    required this.onPressed,
    required this.controller,
    this.onFieldSubmitted,
    required this.onSuffixPressed,
    this.autofocus = true,
    this.filterButton,
  });

  @override
  State<SeachFormTextField> createState() => _SeachFormTextFieldState();
}

class _SeachFormTextFieldState extends State<SeachFormTextField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  late final AnimationController _ctrl;
  late final Animation<double> _focusAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _focusAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
      setState(() {});
    });
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final focused = _focus.hasFocus;

    return Flexible(
      child: AnimatedBuilder(
        animation: _focusAnim,
        builder: (context, child) {
          final t = _focusAnim.value;
          final borderColor = Color.lerp(
            Colors.transparent,
            cs.primary.withValues(alpha: 0.55),
            t,
          )!;
          final shadowColor = cs.primary.withValues(alpha: t * 0.18);
          final fillColor = isDark
              ? Color.lerp(
                  cs.surfaceContainerHigh,
                  cs.surfaceContainerHighest,
                  t * 0.4,
                )!
              : Color.lerp(
                  cs.surfaceContainerHigh,
                  cs.surface,
                  t * 0.5,
                )!;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.4),
              boxShadow: [
                if (t > 0)
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
              ],
            ),
            child: Row(
              children: [
                // ── Back arrow ──────────────────────────────────────────
                GestureDetector(
                  onTap: widget.onPressed,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Broken.arrow_left_2,
                      size: 20,
                      color: focused
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),

                // ── Text field ──────────────────────────────────────────
                Expanded(
                  child: TextFormField(
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    controller: widget.controller,
                    keyboardType: TextInputType.text,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                    onChanged: (v) {
                      widget.onChanged?.call(v);
                      setState(() {});
                    },
                    onFieldSubmitted: widget.onFieldSubmitted,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.search,
                      hintStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.38),
                        fontSize: 14.5,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                // ── Clear button ────────────────────────────────────────
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: widget.controller.text.isNotEmpty ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: () {
                      widget.onSuffixPressed();
                      setState(() {});
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Broken.close_circle,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.40),
                      ),
                    ),
                  ),
                ),

                // ── Optional filter button ──────────────────────────────
                if (widget.filterButton != null) ...[
                  widget.filterButton!,
                  const SizedBox(width: 6),
                ],

                // Padding when no filter button
                if (widget.filterButton == null) const SizedBox(width: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}
