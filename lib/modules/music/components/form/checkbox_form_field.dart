import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter/material.dart';

class CheckboxFormBuilderField extends StatelessWidget {
  final String name;
  final FormFieldValidator<bool>? validator;

  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final Widget? trailing;
  final bool tristate;
  const CheckboxFormBuilderField({
    super.key,
    required this.name,
    this.validator,
    this.onChanged,
    this.leading,
    this.trailing,
    this.tristate = false,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<bool>(
      name: name,
      validator: validator,
      builder: (field) {
        final checkboxValue = tristate && field.value == null
            ? null
            : field.value == true
                ? true
                : false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Checkbox(
              value: checkboxValue,
              onChanged: (state) {
                field.didChange(state == true);
                onChanged?.call(state ?? false);
              },
              tristate: tristate,
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        );
      },
    );
  }
}
