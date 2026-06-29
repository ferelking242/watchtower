import 'package:flutter/material.dart' show ListTileTheme, ListTileThemeData, Material, MaterialType;
  import 'package:shadcn_flutter/shadcn_flutter.dart' hide Theme, ThemeData;
  import 'package:shadcn_flutter/shadcn_flutter_extension.dart';

  class SectionCardWithHeading extends StatelessWidget {
    final String heading;
    final List<Widget> children;
    const SectionCardWithHeading({
      super.key,
      required this.heading,
      required this.children,
    });

    @override
    Widget build(BuildContext context) {
      return ListTileTheme(
        data: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: context.theme.borderRadiusLg,
            side: BorderSide(
              color: context.theme.colorScheme.border,
              width: .5,
            ),
          ),
          textColor: context.theme.colorScheme.foreground,
          iconColor: context.theme.colorScheme.foreground,
          selectedColor: context.theme.colorScheme.accent,
          subtitleTextStyle: context.theme.typography.xSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                heading,
                style: context.theme.typography.large.copyWith(
                  color: context.theme.colorScheme.foreground,
                ),
              ),
            ),
            // Material(transparency) is required here because ListTile renders
            // Ink(decoration: ShapeDecoration(shape: ...)) when a shape is set
            // in ListTileTheme. Ink calls Material.of(context)! and crashes if
            // no Material ancestor is found. shadcn.Scaffold wraps its content
            // in Overlay entries, and depending on the rendering path the Material
            // from the page scaffold may not be in the ancestor chain.
            Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ).gap(8.0),
              ),
            ),
          ],
        ),
      );
    }
  }
  