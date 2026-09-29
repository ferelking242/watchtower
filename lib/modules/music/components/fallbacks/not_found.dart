import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

class NotFound extends StatelessWidget {
  const NotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Undraw(
          illustration: UndrawIllustration.empty,
          height: 200 * 1.0,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: 10),
        Text(
          context.l10n.nothing_found,
          textAlign: TextAlign.center,
        )
      ],
    );
  }
}
