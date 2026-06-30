import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/components/form/text_form_field.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

class SettingsPlaybackEditInstanceUrlDialog extends HookConsumerWidget {
  final String title;
  final String? initialValue;
  final ValueChanged<String> onSave;

  const SettingsPlaybackEditInstanceUrlDialog({
    super.key,
    required this.title,
    required this.onSave,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context, ref) {
    final controller = useTextEditingController(
      text: initialValue,
    );
    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);

    return Alert(
      title: Text(title).h4(),
      content: FormBuilder(
        key: formKey,
        child: Column(
          children: [
            SizedBox(height: 10),
            TextFormBuilderField(
              name: "url",
              controller: controller,
              placeholder: Text(title),
              validator: FormBuilderValidators.url(),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(context.l10n.cancel),
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.saveAndValidate()) {
                        return;
                      }
                      onSave(
                        controller.text,
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text(context.l10n.save),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
