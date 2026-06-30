import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/components/form/text_form_field.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

class SettingsPlaybackEditConnectPortDialog extends HookConsumerWidget {
  const SettingsPlaybackEditConnectPortDialog({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final connectPort = ref.watch(
      userPreferencesProvider.select((s) => s.connectPort),
    );
    final controller = useTextEditingController(
      text: connectPort.toString(),
    );
    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        title: Text(
          context.l10n.edit_port,
          style: theme.textTheme.headlineSmall,
        ),
        content: FormBuilder(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              TextFormBuilderField(
                name: "port",
                controller: controller,
                placeholder: const Text("3000"),
                validator: FormBuilderValidators.integer(radix: 10),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) {
                      if (newValue.text.isEmpty) {
                        return const TextEditingValue();
                      }
                      if (newValue.text.length == 1 && newValue.text == "-") {
                        return newValue;
                      }
                      final intValue = int.tryParse(newValue.text);
                      if (intValue == null) {
                        return oldValue;
                      }
                      return newValue;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.port_helper_msg,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!formKey.currentState!.saveAndValidate()) {
                          return;
                        }
                        final port = int.parse(controller.text);
                        ref
                            .read(userPreferencesProvider.notifier)
                            .setConnectPort(port);
                        Navigator.of(context).pop();
                      },
                      child: Text(context.l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
