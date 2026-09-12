import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label, this.size = 24, this.color});
  final String? label;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? AppLocalizations.of(context)!.loading,
    liveRegion: true,
    child: SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    ),
  );
}
