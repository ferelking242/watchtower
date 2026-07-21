import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class TextFormBuilderField extends StatelessWidget {
  final String name;
  final FormFieldValidator<String>? validator;
  final Widget? label;
  final Widget? placeholder;
  final TextEditingController? controller;
  final bool filled;
  final bool obscureText;
  final String obscuringCharacter;
  final bool enabled;
  final bool readOnly;
  final bool expands;
  final bool autofocus;
  final String? initialValue;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final UndoHistoryController? undoController;
  final void Function(PointerDownEvent)? onTapOutside;
  final Clip clipBehavior;
  final WidgetStatesController? statesController;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  const TextFormBuilderField({
    super.key,
    required this.name,
    this.label,
    this.validator,
    this.controller,
    this.maxLength,
    this.maxLengthEnforcement,
    this.maxLines = 1,
    this.minLines,
    this.filled = false,
    this.placeholder,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.initialValue,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.expands = false,
    this.textAlignVertical = TextAlignVertical.center,
    this.autofillHints,
    this.undoController,
    this.onChanged,
    this.onTapOutside,
    this.inputFormatters,
    this.style,
    this.textInputAction,
    this.clipBehavior = Clip.hardEdge,
    this.autofocus = false,
    this.statesController,
    this.padding,
    this.borderRadius,
    this.focusNode,
    this.onTap,
    this.onEditingComplete,
    this.onSubmitted,
    this.suffixIcon,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormBuilderField<String>(
      name: name,
      validator: validator,
      onChanged: (value) {
        if (value == null) return;
        onChanged?.call(value);
      },
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            DefaultTextStyle(
              style: theme.textTheme.bodyMedium!
                  .copyWith(fontWeight: FontWeight.w600)
                  .copyWith(
                    color: field.hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
              child: label!,
            ),
            const SizedBox(height: 5),
          ],
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLengthEnforcement: maxLengthEnforcement,
            maxLines: maxLines,
            minLines: minLines,
            onSubmitted: (value) {
              field.validate();
              field.save();
              onSubmitted?.call(value);
            },
            onEditingComplete: () {
              field.save();
              onEditingComplete?.call();
            },
            focusNode: focusNode,
            onTap: onTap,
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscureText,
            obscuringCharacter: obscuringCharacter,
            textAlign: textAlign,
            expands: expands,
            textAlignVertical: textAlignVertical,
            autofillHints: autofillHints,
            undoController: undoController,
            onChanged: (value) {
              field.didChange(value);
            },
            onTapOutside: onTapOutside,
            inputFormatters: inputFormatters,
            style: style,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            clipBehavior: clipBehavior,
            autofocus: autofocus,
            statesController: statesController,
            decoration: InputDecoration(
              hintText:
                  placeholder is Text ? (placeholder as Text).data : null,
              hintStyle: placeholder is Text
                  ? (placeholder as Text).style
                  : null,
              errorText: field.hasError ? field.errorText : null,
              filled: filled,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              contentPadding: padding,
              border: OutlineInputBorder(
                borderRadius: borderRadius != null
                    ? (borderRadius as BorderRadius)
                    : BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
