import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/components/markdown/markdown.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';

class SettingsMetadataProviderFormPage extends HookConsumerWidget {
  final String title;
  final List<MetadataFormFieldObject> fields;
  const SettingsMetadataProviderFormPage({
    super.key,
    required this.title,
    required this.fields,
  });

  @override
  Widget build(BuildContext context, ref) {
    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);
    final obscuredPasswords = useState<Map<String, bool>>({});

    return FormBuilder(
      key: formKey,
      child: SettingsSubpageScaffold(
        title: title,
        showSearch: false,
        leading: const MusicBackButton(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in fields) ...[
                    _buildField(context, field, obscuredPasswords),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState?.saveAndValidate() != true) {
                        return;
                      }
                      final data = formKey.currentState!.value.entries
                          .map(
                            (e) => <String, dynamic>{
                              'id': e.key,
                              'value': e.value,
                            },
                          )
                          .toList();
                      context.router.maybePop(data);
                    },
                    child: Text(context.l10n.submit),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    MetadataFormFieldObject field,
    ValueNotifier<Map<String, bool>> obscuredPasswords,
  ) {
    if (field is MetadataFormFieldTextObject) {
      return AppMarkdown(data: field.text);
    }

    final input = field as MetadataFormFieldInputObject;
    final isPassword = input.variant == FormFieldVariant.password;
    final isObscured = obscuredPasswords.value[input.id] ?? true;

    return FormBuilderField(
      name: input.id,
      initialValue: input.defaultValue,
      validator: FormBuilderValidators.compose([
        if (input.required == true)
          FormBuilderValidators.required(
            errorText: context.l10n.field_is_required,
          ),
        if (input.regex != null)
          FormBuilderValidators.match(
            RegExp(input.regex!),
            errorText: context.l10n.input_does_not_match_format,
          ),
      ]),
      builder: (formField) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: input.placeholder,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(isObscured ? Broken.eye : Broken.eye_slash),
                        onPressed: () {
                          obscuredPasswords.value = {
                            ...obscuredPasswords.value,
                            input.id: !isObscured,
                          };
                        },
                      )
                    : null,
              ),
              onChanged: formField.didChange,
              obscureText: isPassword && isObscured,
              keyboardType: input.variant == FormFieldVariant.number
                  ? TextInputType.number
                  : TextInputType.text,
            ),
            if (formField.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  formField.errorText ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
