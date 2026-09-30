part of 'volunteer_workspace.dart';

extension _VolunteerAccountViews on _VolunteerWorkspaceState {
  List<Widget> _badge() => [
    const SizedBox(height: 72),
    VolunteerBadgeCard(account: account),
    const SizedBox(height: 72),
  ];
  List<Widget> _profile() => [
    ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s.profile,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    GuardianSummary(
      name: dataText(context, account.name),
      role: s.volunteerRole,
      identifier: account.volunteerId,
    ),
    const SizedBox(height: 24),
    Text(
      s.accountInformation,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
    const SizedBox(height: 12),
    GuardianPanel(
      child: Column(
        children: [
          _profileInfo(
            s.fullName,
            dataText(context, account.name),
            Icons.person_outline,
          ),
          const Divider(height: 24),
          _profileInfo(
            s.email,
            account.email ?? '—',
            Icons.email_outlined,
            ltr: true,
          ),
          const Divider(height: 24),
          _profileInfo(
            s.phone,
            account.phone ?? '—',
            Icons.phone_outlined,
            ltr: true,
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    Text(
      s.language,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
    const SizedBox(height: 12),
    GuardianPanel(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.language, color: AppColors.secondary),
        title: Text(s.language),
        subtitle: Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? s.arabicLanguage
              : s.englishLanguage,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.secondary,
        ),
        onTap: _chooseLanguage,
      ),
    ),
    const SizedBox(height: 32),
    OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
      ),
      icon: const Icon(Icons.logout),
      label: Text(s.logout),
      onPressed: _busy
          ? null
          : () async {
              final confirmed = await guardianConfirmation(
                context,
                title: s.logoutTitle,
                message: s.logoutMessage,
                confirm: s.logout,
                icon: Icons.logout,
              );
              if (confirmed == true && mounted) {
                await _run(_logout, requiresLocation: false);
              }
            },
    ),
  ];

  Widget _profileInfo(
    String label,
    String value,
    IconData icon, {
    bool ltr = false,
  }) => Row(
    children: [
      Icon(icon, color: const Color(0xFF718096), size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(fontSize: 14, color: AppColors.primary),
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> _chooseLanguage() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VolunteerHeading(s.vLanguage),
          const SizedBox(height: 12),
          for (final language in ['ar', 'en'])
            ListTile(
              title: Text(language == 'ar' ? 'العربية' : 'English'),
              trailing: Localizations.localeOf(context).languageCode == language
                  ? const Icon(Icons.check, color: volunteerTeal)
                  : null,
              onTap: () {
                AppLocaleScope.of(context).setLocale(Locale(language));
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class VolunteerBadgeCard extends StatefulWidget {
  const VolunteerBadgeCard({super.key, required this.account});
  final VolunteerAccount account;
  @override
  State<VolunteerBadgeCard> createState() => _VolunteerBadgeCardState();
}

class _VolunteerBadgeCardState extends State<VolunteerBadgeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant VolunteerBadgeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.account.assignedToCurrentEvent &&
        !MediaQuery.disableAnimationsOf(context)) {
      _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(context), a = widget.account;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => CustomPaint(
        foregroundPainter: a.assignedToCurrentEvent
            ? _BadgeBorder(_animation.value)
            : null,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: a.assignedToCurrentEvent
                ? const Color(0xFFB2E7DB)
                : const Color(0xFFB91C1C),
          ),
          boxShadow: a.assignedToCurrentEvent
              ? const [BoxShadow(color: Color(0x2065CDB1), blurRadius: 18)]
              : null,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/radd_logo.png',
                  width: 48,
                  height: 58,
                  semanticLabel: s.appTitle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.appTitle,
                        style: const TextStyle(
                          color: volunteerNavy,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        a.assignedToCurrentEvent
                            ? s.vEventAuthorized
                            : s.vEventUnassigned,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: VolunteerChip(
                a.assignedToCurrentEvent
                    ? s.vEventAuthorized
                    : s.vEventUnassigned,
                color: a.assignedToCurrentEvent
                    ? volunteerGreen
                    : const Color(0xFFB91C1C),
                dot: true,
              ),
            ),
            if (a.eventAuthorized &&
                (a.eventName?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Text(
                s.vBadgeEventName(a.eventName!),
                textAlign: TextAlign.center,
              ),
            ],
            const Divider(height: 36),
            Text('${s.vAccountStatus}: ${a.active ? s.vActive : s.vInactive}'),
            const SizedBox(height: 20),
            Text(
              s.vVolunteerName,
              style: const TextStyle(color: Color(0xFF747783), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              dataText(context, a.name),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B3D91),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: volunteerTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text(
                    s.vVolunteerId,
                    style: const TextStyle(
                      color: Color(0xFF747783),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    a.volunteerId,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: volunteerNavy,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _BadgeBorder extends CustomPainter {
  _BadgeBorder(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)),
      );
    final metric = path.computeMetrics().first;
    final start = value * metric.length, end = start + metric.length * .28;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF25BD95)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      metric.extractPath(start, math.min(end, metric.length)),
      paint,
    );
    if (end > metric.length) {
      canvas.drawPath(metric.extractPath(0, end - metric.length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeBorder oldDelegate) =>
      value != oldDelegate.value;
}
