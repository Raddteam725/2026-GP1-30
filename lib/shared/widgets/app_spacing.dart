import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const pagePadding = EdgeInsetsDirectional.symmetric(horizontal: lg);
}

class Gap extends StatelessWidget {
  const Gap(this.size, {super.key}) : axis = Axis.vertical;
  const Gap.horizontal(this.size, {super.key}) : axis = Axis.horizontal;
  final double size;
  final Axis axis;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: axis == Axis.horizontal ? size : 0,
    height: axis == Axis.vertical ? size : 0,
  );
}
