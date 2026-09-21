import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../guardian/presentation/guardian_components.dart';
import '../domain/volunteer_models.dart';

const volunteerCanvas = Color(0xFFF9FBFD);
const volunteerInk = AppColors.primary;
const volunteerNavy = AppColors.primary;
const volunteerTeal = AppColors.secondary;
const volunteerTint = Color(0xFFF1F3FF);
const volunteerBorder = AppColors.border;
const volunteerGreen = Color(0xFF078461);
AppLocalizations stringsOf(BuildContext context) =>
    AppLocalizations.of(context)!;
String dataText(BuildContext context, LocalizedData value) =>
    value.inLanguage(Localizations.localeOf(context).languageCode);
String relationshipText(BuildContext context, LocalizedData value) =>
    switch (value.en) {
      'child' => stringsOf(context).child,
      'parent' => stringsOf(context).parent,
      'other' => stringsOf(context).other,
      _ => dataText(context, value),
    };
String numberText(BuildContext context, num value) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode)
        .format(value);
String timeText(BuildContext context, DateTime date) =>
    DateFormat.MMMd(Localizations.localeOf(context).languageCode)
        .add_jm()
        .format(date.toLocal());
String statusText(AppLocalizations s, CaseStatus status) => switch (status) {
  CaseStatus.reportReceived => s.vReportReceived,
  CaseStatus.searchInProgress => s.vSearchProgress,
  CaseStatus.matchConfirmed => s.vMatchConfirmed,
  CaseStatus.awaitingGuardianVerification => s.vAwaitingGuardian,
  CaseStatus.reunited => s.vReunited,
};
Color statusColor(CaseStatus status) => switch (status) {
  CaseStatus.reportReceived ||
  CaseStatus.awaitingGuardianVerification => const Color(0xFF996A00),
  CaseStatus.searchInProgress || CaseStatus.matchConfirmed => volunteerTeal,
  CaseStatus.reunited => volunteerGreen,
};

class VolunteerCard extends StatelessWidget {
  const VolunteerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
    this.border = const Color(0xB3E5E7EB),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color, border;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GuardianPanel(
      padding: EdgeInsets.zero,
      color: color,
      border: border,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class VolunteerHeading extends StatelessWidget {
  const VolunteerHeading(
    this.text, {
    super.key,
    this.large = false,
    this.color = volunteerInk,
  });
  final String text;
  final bool large;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: large ? 28 : 20,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.3,
    ),
  );
}

class VolunteerChip extends StatelessWidget {
  const VolunteerChip(
    this.label, {
    super.key,
    this.color = volunteerTeal,
    this.dot = false,
  });
  final String label;
  final Color color;
  final bool dot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      '${dot ? '●  ' : ''}$label',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        height: 1.25,
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final CaseStatus status;
  @override
  Widget build(BuildContext context) => VolunteerChip(
    statusText(stringsOf(context), status),
    color: statusColor(status),
    dot: true,
  );
}

class VolunteerAction extends StatelessWidget {
  const VolunteerAction(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary, danger;
  @override
  Widget build(BuildContext context) {
    final content = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        if (icon != null) Icon(icon, size: 22),
        Text(label, textAlign: TextAlign.center),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: secondary || danger
          ? OutlinedButton(
              onPressed: onPressed,
              style: danger
                  ? OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    )
                  : null,
              child: content,
            )
          : FilledButton(onPressed: onPressed, child: content),
    );
  }
}

class PersonPhoto extends StatelessWidget {
  const PersonPhoto(
    this.person, {
    super.key,
    this.size = 64,
    this.height,
    this.radius = 12,
  });
  final RegisteredPerson person;
  final double size, radius;
  final double? height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: size,
      height: height ?? size,
      child: person.photoBytes != null
          ? Image.memory(
              person.photoBytes!,
              fit: BoxFit.cover,
              semanticLabel: dataText(context, person.name),
              errorBuilder: (_, _, _) => _fallback(),
            )
          : person.photo != null
          ? Image.asset(
              person.photo!,
              fit: BoxFit.cover,
              semanticLabel: dataText(context, person.name),
              errorBuilder: (_, _, _) => _fallback(),
            )
          : _fallback(),
    ),
  );
  Widget _fallback() => ColoredBox(
    color: const Color(0xFFE8EDFF),
    child: Icon(
      Icons.person_outline,
      color: volunteerNavy,
      size: height == null ? size * .55 : 64,
    ),
  );
}

class VolunteerInfo extends StatelessWidget {
  const VolunteerInfo(
    this.message, {
    super.key,
    this.title,
    this.icon = Icons.info_outline,
    this.color = volunteerTeal,
  });
  final String message;
  final String? title;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => VolunteerCard(
    color: volunteerTint,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message,
                style: const TextStyle(color: Color(0xFF434652), height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class VolunteerDetail extends StatelessWidget {
  const VolunteerDetail(
    this.label,
    this.value, {
    super.key,
    this.icon,
    this.ltr = false,
  });
  final String label, value;
  final IconData? icon;
  final bool ltr;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: volunteerTeal, size: 22),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF747783), fontSize: 13),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                textDirection: ltr ? TextDirection.ltr : null,
                style: const TextStyle(
                  color: volunteerInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class VolunteerBell extends StatelessWidget {
  const VolunteerBell({
    super.key,
    required this.onPressed,
    this.hasAlerts = false,
  });
  final VoidCallback onPressed;
  final bool hasAlerts;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 16),
    child: IconButton(
      tooltip: stringsOf(context).vNotifications,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: volunteerBorder),
      ),
      icon: Badge(
        isLabelVisible: hasAlerts,
        smallSize: 7,
        backgroundColor: AppColors.accent,
        child: const Icon(
          Icons.notifications_none_rounded,
          color: volunteerNavy,
        ),
      ),
    ),
  );
}

class VolunteerEmpty extends StatelessWidget {
  const VolunteerEmpty(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext context) => VolunteerCard(
    child: Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.folder_open_rounded, size: 42, color: volunteerTeal),
        const SizedBox(height: 16),
        VolunteerHeading(title),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
      ],
    ),
  );
}
