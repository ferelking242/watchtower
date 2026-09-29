import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/modules/music/collections/spotube_icons.dart';

class ZoomControls extends HookWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int? min;
  final int? max;

  final int interval;
  final Icon increaseIcon;
  final Icon decreaseIcon;

  final Axis direction;
  final String unit;

  const ZoomControls({
    super.key,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.interval = 10,
    this.increaseIcon = const Icon(SpotubeIcons.zoomIn),
    this.decreaseIcon = const Icon(SpotubeIcons.zoomOut),
    this.direction = Axis.horizontal,
    this.unit = "%",
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      IconButton(
        icon: decreaseIcon,
        onPressed: () {
          if (value == min) return;
          onChanged(value - interval);
        },
      ),
      Text("$value$unit"),
      IconButton(
        icon: increaseIcon,
        onPressed: () {
          if (value == max) return;
          onChanged(value + interval);
        },
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: direction == Axis.horizontal ? 50 : 200,
        maxWidth: direction == Axis.vertical ? 50 : double.infinity,
      ),
      margin: const EdgeInsets.all(8),
      child: Card(
        child: direction == Axis.horizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: actions,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                verticalDirection: VerticalDirection.up,
                children: actions,
              ),
      ),
    );
  }
}
