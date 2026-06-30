import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';

class MusicBackButton extends StatelessWidget {
  final Color? color;
  final IconData icon;
  const BackButton({
    super.key,
    this.color,
    this.icon = SpotubeIcons.angleLeft,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}
