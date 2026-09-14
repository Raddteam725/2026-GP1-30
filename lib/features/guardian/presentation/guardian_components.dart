import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';

class GuardianNavigation extends StatelessWidget {
  const GuardianNavigation({
    super.key,
    required this.selected,
    this.onSelected,
    this.enabled = true,
  });
  final int selected;
  final ValueChanged<int>? onSelected;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final labels = [s.home, s.myIndividuals, s.qrCode, s.cases, s.profile];
    const icons = [
      Icons.home_outlined,
      Icons.people_outline,
      Icons.qr_code_2,
      Icons.folder_outlined,
      Icons.person_outline,
    ];
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: Semantics(
                      selected: selected == i,
                      button: true,
                      child: InkWell(
                        onTap: !enabled
                            ? null
                            : () {
                                if (i == 2 || i == 3) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(s.comingLater)),
                                  );
                                  return;
                                }
                                if (onSelected != null) {
                                  onSelected!(i);
                                } else {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    AppRoutes.guardian,
                                    (_) => false,
                                    arguments: i,
                                  );
                                }
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 3,
                                width: 24,
                                decoration: BoxDecoration(
                                  color: selected == i
                                      ? AppColors.secondary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                icons[i],
                                size: 24,
                                color: selected == i
                                    ? AppColors.primary
                                    : const Color(0xFF718096),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: selected == i
                                      ? AppColors.primary
                                      : const Color(0xFF718096),
                                  fontWeight: selected == i
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuardianPanel extends StatelessWidget {
  const GuardianPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border.withValues(alpha: .7)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .025),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class RequiredLabel extends StatelessWidget {
  const RequiredLabel(this.label, {super.key, this.required = true});
  final String label;
  final bool required;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: label,
      children: [
        if (required)
          const TextSpan(
            text: ' *',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
    style: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );
}

class GuardianSummary extends StatelessWidget {
  const GuardianSummary({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => GuardianPanel(
    child: Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFE4F7F9),
          child: Icon(Icons.person_outline, color: AppColors.secondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.guardianRole,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PhotoAvatar extends StatelessWidget {
  const PhotoAvatar({super.key, this.child, this.onTap, this.size = 128});
  final Widget? child;
  final VoidCallback? onTap;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size + 16,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: _DashedCircle(),
          child: SizedBox.square(
            dimension: size,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child:
                    child ??
                    const ColoredBox(
                      color: Color(0xFFF0F5F8),
                      child: Icon(
                        Icons.person_outline,
                        size: 56,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 4,
          child: IconButton.filled(
            tooltip: AppLocalizations.of(context)!.takePhoto,
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
          ),
        ),
      ],
    ),
  );
}

class _DashedCircle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    for (double a = 0; a < math.pi * 2; a += .18) {
      canvas.drawArc(rect.deflate(1), a, .09, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle oldDelegate) => false;
}

Future<bool?> guardianConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  required IconData icon,
}) {
  final s = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      icon: Icon(icon, color: AppColors.error, size: 32),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
}
