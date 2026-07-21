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
    final langCode = lang.toLowerCase();
    final flag = langFlagEmoji(langCode);
    final name = completeLanguageName(langCode);

    return ListTile(
      onTap: () => onChanged(!value),
      onLongPress: onLongPress,
      leading: Text(
        flag,
        style: const TextStyle(fontSize: 26),
      ),
      title: Text(name),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
