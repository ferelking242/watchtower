import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/extension/providers/extension_preferences_providers.dart';
import 'package:watchtower/services/get_source_preference.dart';
import 'package:watchtower/services/http/m_client.dart';

class SourcePreferenceWidget extends StatefulWidget {
  final List<SourcePreference> sourcePreference;
  final Source source;

  const SourcePreferenceWidget({
    super.key,
    required this.sourcePreference,
    required this.source,
  });

  @override
  State<SourcePreferenceWidget> createState() => _SourcePreferenceWidgetState();
}

class _SourcePreferenceWidgetState extends State<SourcePreferenceWidget> {
  final Map<String, TextEditingController> _textControllers = {};

  TextStyle? get _settingTitleStyle =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.25,
          );

  TextStyle? get _settingSummaryStyle =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.35,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  TextEditingController _controllerFor(
    SourcePreference preference,
    int index,
  ) {
    final key = preference.key ?? 'preference_$index';
    return _textControllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: preference.editTextPreference?.value ?? '',
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save(SourcePreference preference) {
    setPreferenceSetting(preference, widget.source);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _saveSwitch(
    SourcePreference preference,
    bool value,
  ) async {
    setPreferenceSetting(preference, widget.source);
    if (preference.key == extensionKeepSessionKey &&
        !value &&
        (widget.source.baseUrl?.isNotEmpty ?? false)) {
      await MClient.deleteAllCookies(widget.source.baseUrl!);
    }
  }

  Widget _expandableSetting({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title, style: _settingTitleStyle),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _settingSummaryStyle,
      ),
      children: children,
    );
  }

  Widget _buildPreference(SourcePreference preference, int index) {
    if (preference.editTextPreference case final pref?) {
      final controller = _controllerFor(preference, index);
      final sensitive = RegExp(
        r'password|token|secret|cookie|api.?key',
        caseSensitive: false,
      ).hasMatch(preference.key ?? '');
      return _expandableSetting(
        title: pref.title ?? preference.key ?? 'Réglage',
        subtitle: controller.text.isNotEmpty
            ? (sensitive ? 'Valeur enregistrée' : controller.text)
            : (pref.summary ?? ''),
        children: [
          TextField(
            controller: controller,
            obscureText: sensitive,
            minLines: 1,
            maxLines: sensitive ? 1 : 4,
            decoration: InputDecoration(
              labelText: pref.dialogTitle?.isNotEmpty == true
                  ? pref.dialogTitle
                  : pref.title,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              helperText: pref.dialogMessage?.isNotEmpty == true
                  ? pref.dialogMessage
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                pref.value = controller.text;
                _save(preference);
                setState(() {});
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer'),
            ),
          ),
        ],
      );
    }

    if (preference.checkBoxPreference case final pref?) {
      return CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(pref.title ?? '', style: _settingTitleStyle),
        subtitle: Text(
          pref.summary ?? '',
          style: _settingSummaryStyle,
        ),
        value: pref.value ?? false,
        controlAffinity: ListTileControlAffinity.trailing,
        onChanged: (value) {
          setState(() => pref.value = value);
          _save(preference);
        },
      );
    }

    if (preference.switchPreferenceCompat case final pref?) {
      return SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(pref.title ?? '', style: _settingTitleStyle),
        subtitle: Text(
          pref.summary ?? '',
          style: _settingSummaryStyle,
        ),
        value: pref.value ?? false,
        controlAffinity: ListTileControlAffinity.trailing,
        onChanged: (value) async {
          setState(() => pref.value = value);
          await _saveSwitch(preference, value);
        },
      );
    }

    if (preference.listPreference case final pref?) {
      final entries = pref.entries ?? const <String>[];
      if (entries.isEmpty) return const SizedBox.shrink();
      final selected =
          (pref.valueIndex ?? 0).clamp(0, entries.length - 1).toInt();
      return _expandableSetting(
        title: pref.title ?? preference.key ?? 'Choix',
        subtitle: entries[selected],
        children: [
          RadioGroup<int>(
            groupValue: selected,
            onChanged: (value) {
              if (value == null) return;
              setState(() => pref.valueIndex = value);
              _save(preference);
            },
            child: Column(
              children: [
                for (var option = 0; option < entries.length; option++)
                  RadioListTile<int>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: option,
                    title: Text(entries[option], style: _settingTitleStyle),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if (preference.multiSelectListPreference case final pref?) {
      final entries = pref.entries ?? const <String>[];
      final values = pref.entryValues ?? const <String>[];
      final selectedValues = <String>{...?pref.values};
      final selectedLabels = [
        for (var option = 0;
            option < entries.length && option < values.length;
            option++)
          if (selectedValues.contains(values[option])) entries[option],
      ];
      return _expandableSetting(
        title: pref.title ?? preference.key ?? 'Choix multiples',
        subtitle: selectedLabels.isEmpty
            ? (pref.summary ?? '')
            : selectedLabels.join(', '),
        children: [
          for (var option = 0;
              option < entries.length && option < values.length;
              option++)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entries[option], style: _settingTitleStyle),
              value: selectedValues.contains(values[option]),
              onChanged: (checked) {
                if (checked == true) {
                  selectedValues.add(values[option]);
                } else {
                  selectedValues.remove(values[option]);
                }
                pref.values = values
                    .where(selectedValues.contains)
                    .toList(growable: false);
                setState(() {});
                _save(preference);
              },
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var index = 0; index < widget.sourcePreference.length; index++)
            _buildPreference(widget.sourcePreference[index], index),
        ],
      );
}