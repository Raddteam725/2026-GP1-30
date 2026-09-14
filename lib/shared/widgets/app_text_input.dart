import 'package:flutter/material.dart';

class AppTextInput extends StatelessWidget {
  const AppTextInput({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.enabled = true,
    this.showLabel = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.textDirection,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final bool enabled;
  final bool showLabel;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int maxLines;
  final TextDirection? textDirection;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    validator: validator,
    onChanged: onChanged,
    onFieldSubmitted: onFieldSubmitted,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    enabled: enabled,
    obscureText: obscureText,
    autocorrect: autocorrect,
    enableSuggestions: enableSuggestions,
    maxLines: obscureText ? 1 : maxLines,
    textDirection: textDirection,
    decoration: InputDecoration(
      labelText: showLabel ? label : null,
      hintText: hint,
      errorMaxLines: 3,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
    ),
  );
}
