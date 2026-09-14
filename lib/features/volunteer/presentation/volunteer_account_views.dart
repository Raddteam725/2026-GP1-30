part of 'volunteer_workspace.dart';

extension _VolunteerAccountViews on _VolunteerWorkspaceState {
  List<Widget> _badge() => [
    const SizedBox(height: 72),
    VolunteerBadgeCard(account: account),
    const SizedBox(height: 72),
  ];
  List<Widget> _profile() => [
    VolunteerCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: volunteerNavy,
            child: Text(
              dataText(context, account.name).isEmpty
                  ? ''
                  : dataText(context, account.name).substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VolunteerHeading(dataText(context, account.name)),
                const SizedBox(height: 8),
                VolunteerChip(s.volunteerRole, color: volunteerNavy, dot: true),
              ],
            ),
          ),
        ],
      ),
    ),
    VolunteerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              VolunteerHeading(s.vAccountInformation),
              VolunteerChip(
                account.active ? s.vActive : s.vInactive,
                color: account.active ? volunteerGreen : Colors.red.shade700,
                dot: true,
              ),
            ],
          ),
          const Divider(height: 28),
          VolunteerDetail(s.vFullName, dataText(context, account.name)),
          if (account.email != null)
            VolunteerDetail(s.vEmail, account.email!, ltr: true),
          if (account.phone != null)
            VolunteerDetail(s.vPhone, account.phone!, ltr: true),
          VolunteerDetail(s.vVolunteerId, account.volunteerId, ltr: true),
        ],
      ),
    ),
    VolunteerCard(
      onTap: _chooseLanguage,
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE8EDFF),
            child: Icon(Icons.language, color: volunteerNavy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VolunteerHeading(s.vLanguage),
                const SizedBox(height: 5),
                Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'العربية'
                      : 'English',
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF747783)),
        ],
      ),
    ),
    const SizedBox(height: 12),
    VolunteerAction(
      s.vLogout,
      danger: true,
      icon: Icons.logout,
      onPressed: _busy
          ? null
          : () async {
              if (!await _confirm(s.vLogout, s.vLogoutQuestion, s.vLogout) ||
                  !mounted) {
                return;
              }
              await _run(widget.onLogout);
            },
    ),
  ];
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
    if (widget.account.active && !MediaQuery.disableAnimationsOf(context)) {
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
        foregroundPainter: a.active ? _BadgeBorder(_animation.value) : null,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: a.active ? const Color(0xFFB2E7DB) : volunteerBorder,
          ),
          boxShadow: a.active
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
                        s.vAuthorized,
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
                a.active ? s.vActive : s.vInactive,
                color: a.active ? volunteerGreen : const Color(0xFFB91C1C),
                dot: true,
              ),
            ),
            const Divider(height: 36),
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
