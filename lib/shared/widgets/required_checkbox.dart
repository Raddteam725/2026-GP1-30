import 'package:flutter/material.dart';

/// A required declaration with field-local interaction and validation state.
class RequiredCheckbox extends StatelessWidget {
  const RequiredCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.errorText,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final Widget label;
  final String errorText;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => FormField<bool>(
    initialValue: value,
    enabled: enabled,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (checked) => checked == true ? null : errorText,
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: field.value ?? false,
          isError: field.hasError,
          title: label,
          onChanged: enabled
              ? (checked) {
                  final next = checked ?? false;
                  field.didChange(next);
                  onChanged(next);
                }
              : null,
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                field.errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
