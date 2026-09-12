import 'package:flutter/material.dart';

import 'loading_state.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expand;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: expand ? double.infinity : null,
    child: FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const LoadingState()
          : Text(label, textAlign: TextAlign.center),
    ),
  );
}
