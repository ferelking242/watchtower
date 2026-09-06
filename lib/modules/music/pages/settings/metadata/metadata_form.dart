import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/components/markdown/markdown.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
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

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: FormBuilder(
          key: formKey,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge!,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverList.separated(
                    itemCount: fields.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12, width: 12),
                    itemBuilder: (context, index) {
                      if (fields[index] is MetadataFormFieldTextObject) {
                        final field =
                            fields[index] as MetadataFormFieldTextObject;
                        return AppMarkdown(data: field.text);
                      }

                      final field =
                          fields[index] as MetadataFormFieldInputObject;
                      return FormBuilderField(
                        name: field.id,
                        initialValue: field.defaultValue,
                        validator: FormBuilderValidators.compose([
                          if (field.required == true)
                            FormBuilderValidators.required(
                              errorText: 'This field is required',
                            ),
                          if (field.regex != null)
                            FormBuilderValidators.match(
                              RegExp(field.regex!),
                              errorText:
                                  context.l10n.input_does_not_match_format,
                            ),
                        ]),
                        builder: (formField) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  hintText: field.placeholder,
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: field.variant == FormFieldVariant.password
                                      ? IconButton(
                                          icon: const Icon(Icons.visibility),
                                          onPressed: () {},
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  formField.didChange(value);
                                },
                                obscureText:
                                    field.variant == FormFieldVariant.password,
                                keyboardType:
                                    field.variant == FormFieldVariant.number
                                        ? TextInputType.number
                                        : TextInputType.text,
                              ),
                              if (formField.hasError)
                                Text(
                                  formField.errorText ?? '',
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: FilledButton(
                      onPressed: () {
                        if (formKey.currentState?.saveAndValidate() != true) {
                          return;
                        }

                        final data = formKey.currentState!.value.entries
                            .map((e) => <String, dynamic>{
                                  "id": e.key,
                                  "value": e.value,
                                })
                            .toList();

                        context.router.maybePop(data);
                      },
                      child: Text(context.l10n.submit),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 200))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
