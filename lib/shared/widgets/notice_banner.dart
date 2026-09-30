import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The transient top-of-screen notice card shared by the Volunteer and
/// Guardian workspaces: title row with icon and close button, a concise
/// message, a context line (individual name or case reference) and one
/// action. Layout is direction-aware (Arabic RTL / English LTR) through the
/// ambient Directionality; the context line may be forced LTR by the caller
/// when it is a Latin identifier.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onOpen,
    required this.onDismiss,
    required this.closeTooltip,
    this.context,
    this.contextTextDirection,
    this.highlighted = false,
    this.icon = Icons.notifications_none,
    this.materialKey,
  });
  final String title, message, actionLabel, closeTooltip;
  final String? context;
  final TextDirection? contextTextDirection;
  final bool highlighted;
  final IconData icon;
  final VoidCallback onOpen, onDismiss;

  /// Key on the Material so callers keep a stable per-event identity.
  final Key? materialKey;

  @override
  Widget build(BuildContext buildContext) {
    return Semantics(
      liveRegion: true,
      child: Material(
        key: materialKey,
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: highlighted ? const Color(0xFFF7B500) : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: highlighted
                        ? const Color(0xFFFFF8E4)
                        : AppColors.secondary.withValues(alpha: .1),
                    child: Icon(
                      icon,
                      color: highlighted
                          ? const Color(0xFF996A00)
                          : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: closeTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(message),
              if (context != null) ...[
                const SizedBox(height: 4),
                Text(
                  context!,
                  textDirection: contextTextDirection,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ],
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: onOpen, child: Text(actionLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
