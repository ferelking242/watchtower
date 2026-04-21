import 'package:flutter/material.dart';
import 'package:watchtower/utils/language.dart';

class ExtensionLangListTileWidget extends StatelessWidget {
  final String lang;
  final bool value;
  final Function(bool) onChanged;
  final VoidCallback? onLongPress;
  const ExtensionLangListTileWidget({
    super.key,
    required this.lang,
    required this.value,
    required this.onChanged,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        onChanged(!value);
      },
      onLongPress: onLongPress,
      title: Text(completeLanguageName(lang.toLowerCase())),
      trailing: Switch(
        value: value,
        onChanged: (value) {
          onChanged(value);
        },
      ),
    );
  }
}
