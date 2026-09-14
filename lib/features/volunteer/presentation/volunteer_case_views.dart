part of 'volunteer_workspace.dart';

extension _VolunteerCaseViews on _VolunteerWorkspaceState {
  List<Widget> _home() {
    final available = repo.availableFor(account.uid);
    final nearby = repo.cases.where(_isNearby).toList();
    return [
      Text(
        dataText(context, account.name),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: volunteerInk,
        ),
      ),
      const SizedBox(height: 16),
      VolunteerCard(
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: volunteerTint,
              child: Icon(Icons.verified_user_outlined, color: volunteerNavy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.vAccount,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    account.volunteerId,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF747783),
                    ),
                  ),
                ],
              ),
            ),
            VolunteerChip(
              account.active ? s.vActive : s.vInactive,
              color: account.active ? volunteerGreen : Colors.red.shade700,
              dot: true,
            ),
          ],
        ),
      ),
      if (!account.active) VolunteerInfo(s.vInactiveHint),
      if (!repo.connected) VolunteerEmpty(s.vNoCases, s.vBackendHint),
      if (_location != null && _location!.coordinates == null) ...[
        VolunteerInfo(
          _location!.unavailable ? s.vLocationUnavailable : s.vLocationHelp,
          title: s.vLocation,
        ),
        VolunteerAction(
          s.vAllowLocation,
          onPressed: _location!.requesting ? null : _location!.request,
          icon: Icons.my_location,
          secondary: true,
        ),
        const SizedBox(height: 24),
      ],
      if (nearby.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF7B500),
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(child: VolunteerHeading(s.vPriorityCases)),
          ],
        ),
        const SizedBox(height: 10),
        VolunteerCard(
          border: const Color(0xFFF7B500),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PersonPhoto(nearby.first.person, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VolunteerHeading(
                          dataText(context, nearby.first.person.name),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nearby.first.id,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        VolunteerChip(
                          s.vNearby,
                          color: const Color(0xFF996A00),
                        ),
                        const SizedBox(height: 6),
                        StatusChip(nearby.first.status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              VolunteerAction(
                s.vViewCase,
                icon: Icons.arrow_forward,
                onPressed: () => _priorityDialog(nearby.first),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: VolunteerHeading(s.vAvailable)),
          TextButton(
            onPressed: () {
              _mine = false;
              _selectTab(1);
            },
            child: Text(s.vViewAll),
          ),
        ],
      ),
      if (available.isEmpty && repo.connected)
        VolunteerEmpty(s.vNoCases, s.vNoCasesHint),
      for (final item in available.take(2)) _compactCase(item),
      const SizedBox(height: 8),
      VolunteerHeading(s.vQuickActions),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            children: [
              SizedBox(
                width: width,
                child: _quickAction(
                  s.vReportFound,
                  Icons.add_a_photo_outlined,
                  () => _selectTab(2),
                ),
              ),
              SizedBox(
                width: width,
                child: _quickAction(
                  s.vDigitalId,
                  Icons.badge_outlined,
                  () => _selectTab(3),
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  Widget _quickAction(String label, IconData icon, VoidCallback action) =>
      VolunteerCard(
        onTap: action,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFD4FBFD),
              child: Icon(icon, color: volunteerTeal),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: volunteerInk,
              ),
            ),
          ],
        ),
      );
  Widget _compactCase(VolunteerCase item) => VolunteerCard(
    padding: const EdgeInsets.all(10),
    onTap: () => _details(item),
    child: Row(
      children: [
        PersonPhoto(item.person, size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dataText(context, item.person.name),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: volunteerInk,
                ),
              ),
              const SizedBox(height: 5),
              StatusChip(item.status),
              const SizedBox(height: 5),
              Text(
                '${item.id} · ${s.vUpdated}: ${timeText(context, item.updatedAt)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF747783)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: Color(0xFF747783)),
      ],
    ),
  );
  List<Widget> _cases() {
    final available = repo.availableFor(account.uid),
        mine = repo.myCases(account.uid),
        items = _mine ? mine : available;
    return [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: volunteerTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: volunteerBorder),
        ),
        child: Row(
          children: [
            Expanded(child: _category(s.vAvailable, available.length, false)),
            Expanded(child: _category(s.vMyCases, mine.length, true)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (!repo.connected) VolunteerInfo(s.vBackendHint),
      if (items.isEmpty) VolunteerEmpty(s.vNoCases, s.vNoCasesHint),
      for (final item in items) _caseCard(item),
    ];
  }

  Widget _category(String title, int count, bool mine) => TextButton(
    key: ValueKey(mine ? 'my-cases' : 'available-cases'),
    onPressed: () => _update(() => _mine = mine),
    style: TextButton.styleFrom(
      backgroundColor: _mine == mine ? Colors.white : Colors.transparent,
      foregroundColor: _mine == mine ? volunteerNavy : const Color(0xFF434652),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(
      '$title  ${numberText(context, count)}',
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
  );
  Widget _caseCard(VolunteerCase item) => VolunteerCard(
    key: ValueKey('case-${item.id}'),
    onTap: () => _details(item),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonPhoto(item.person, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusChip(item.status),
                  const SizedBox(height: 7),
                  VolunteerHeading(dataText(context, item.person.name)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        item.id,
                        style: const TextStyle(
                          color: volunteerNavy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(s.vAgeValue(numberText(context, item.person.age))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${s.vUpdated}: ${timeText(context, item.updatedAt)}',
          style: const TextStyle(color: Color(0xFF747783), fontSize: 12),
        ),
        if (item.information?.lastSeen != null) ...[
          const Divider(height: 24),
          VolunteerDetail(
            s.vLastSeen,
            dataText(context, item.information!.lastSeen!),
            icon: Icons.location_on_outlined,
          ),
        ],
        const SizedBox(height: 16),
        if (item.joinable && !item.joinedBy.contains(account.uid))
          VolunteerAction(
            s.vStartSearch,
            icon: Icons.search,
            onPressed: _busy || !account.active ? null : () => _join(item),
            secondary: item.status == CaseStatus.searchInProgress,
          )
        else
          VolunteerAction(
            s.vViewCase,
            onPressed: () => _details(item),
            secondary: true,
          ),
      ],
    ),
  );
  Future<void> _join(VolunteerCase item) => _run(() async {
    await repo.startSearch(account, item);
    if (mounted) _message(s.vJoined);
  });
  List<Widget> _caseDetails() {
    final item = _case!;
    final info = item.information;
    return [
      LayoutBuilder(
        builder: (context, constraints) => PersonPhoto(
          item.person,
          size: constraints.maxWidth,
          height: constraints.maxWidth * .78,
          radius: 18,
        ),
      ),
      const SizedBox(height: 16),
      VolunteerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VolunteerHeading(dataText(context, item.person.name), large: true),
            const SizedBox(height: 6),
            Text(s.vMissingReport),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VolunteerChip(
                  s.vAgeValue(numberText(context, item.person.age)),
                  color: volunteerNavy,
                ),
                VolunteerChip(
                  item.person.gender == Gender.male ? s.vMale : s.vFemale,
                  color: volunteerNavy,
                ),
                VolunteerChip(item.id),
              ],
            ),
            const Divider(height: 30),
            Text(
              '${s.vUpdated}: ${timeText(context, item.updatedAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF747783)),
            ),
            const SizedBox(height: 10),
            StatusChip(item.status),
          ],
        ),
      ),
      if (info == null)
        VolunteerInfo(
          s.vPendingHint,
          title: s.vPendingDetails,
          color: volunteerNavy,
        ),
      if (info?.lastSeen != null)
        VolunteerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VolunteerHeading(s.vLastSeen),
              VolunteerDetail(
                s.vLastSeen,
                dataText(context, info!.lastSeen!),
                icon: Icons.location_on_outlined,
              ),
              if (_isNearby(item)) VolunteerChip(s.vNearby),
            ],
          ),
        ),
      if (info != null &&
          (info.clothing != null ||
              info.distinctive != null ||
              info.additional != null))
        VolunteerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VolunteerHeading(s.vCaseInformation),
              const Divider(height: 24),
              if (info.clothing != null)
                VolunteerDetail(
                  s.vClothing,
                  dataText(context, info.clothing!),
                  icon: Icons.checkroom,
                ),
              if (info.distinctive != null)
                VolunteerDetail(
                  s.vDistinctive,
                  dataText(context, info.distinctive!),
                  icon: Icons.backpack_outlined,
                ),
              if (info.additional != null)
                VolunteerDetail(
                  s.vAdditional,
                  dataText(context, info.additional!),
                  icon: Icons.info_outline,
                ),
            ],
          ),
        ),
      if (item.joinable && !item.joinedBy.contains(account.uid))
        VolunteerAction(
          s.vStartSearch,
          icon: Icons.search,
          onPressed: _busy || !account.active ? null : () => _join(item),
        ),
      if (item.joinable && item.joinedBy.contains(account.uid))
        VolunteerInfo(s.vSearchJoinedHint),
      if (item.confirmedBy == account.uid &&
          _report?.matchedPerson?.id == item.person.id &&
          item.status != CaseStatus.reunited)
        VolunteerAction(
          s.vGuardianContact,
          onPressed: () => _open(VolunteerView.contact),
        ),
    ];
  }

  List<Widget> _notifications() {
    final alerts = repo
        .alertsFor(account.uid)
        .where((a) => !_priorityOnly || a.kind == AlertKind.priority)
        .toList();
    return [
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text(s.vAllAlerts),
            selected: !_priorityOnly,
            onSelected: (_) => _update(() => _priorityOnly = false),
          ),
          ChoiceChip(
            label: Text(s.vPriorityOnly),
            selected: _priorityOnly,
            onSelected: (_) => _update(() => _priorityOnly = true),
          ),
        ],
      ),
      const SizedBox(height: 24),
      VolunteerHeading(s.vRecentAlerts),
      const SizedBox(height: 16),
      if (!repo.connected) VolunteerInfo(s.vBackendHint),
      if (alerts.isEmpty) VolunteerEmpty(s.vNoAlerts, s.vPriorityHint),
      for (final alert in alerts)
        if (repo.caseById(alert.caseId) != null) _alertCard(alert),
      const SizedBox(height: 12),
      VolunteerInfo(s.vPriorityHint),
    ];
  }

  Widget _alertCard(VolunteerAlert alert) {
    final item = repo.caseById(alert.caseId)!;
    final priority = alert.kind == AlertKind.priority;
    return VolunteerCard(
      border: priority ? const Color(0xFFF7B500) : volunteerBorder,
      onTap: () => _details(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: priority
                    ? const Color(0xFFFFDEA5)
                    : const Color(0xFFE8EDFF),
                child: Icon(
                  priority
                      ? Icons.warning_amber_rounded
                      : alert.kind == AlertKind.newCase
                      ? Icons.folder_open
                      : Icons.check_circle_outline,
                  color: volunteerTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VolunteerHeading(switch (alert.kind) {
                      AlertKind.newCase => s.vNewAlert,
                      AlertKind.priority => s.vPriorityAlert,
                      AlertKind.statusUpdate => s.vStatusAlert,
                    }),
                    const SizedBox(height: 8),
                    Text('${item.id} · ${dataText(context, item.person.name)}'),
                    const SizedBox(height: 8),
                    if (priority)
                      VolunteerChip(s.vNearby, color: const Color(0xFF996A00)),
                    if (alert.status != null) StatusChip(alert.status!),
                    const SizedBox(height: 8),
                    Text(
                      timeText(context, alert.at),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF747783),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _details(item),
              icon: const Icon(Icons.arrow_forward),
              label: Text(s.vViewCase),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _priorityDialog(VolunteerCase item) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VolunteerHeading(s.vPriorityAlert, large: true),
                const SizedBox(height: 12),
                VolunteerChip(s.vNearby, color: const Color(0xFF996A00)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    PersonPhoto(item.person),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VolunteerHeading(dataText(context, item.person.name)),
                          Text(item.id),
                          const SizedBox(height: 8),
                          StatusChip(item.status),
                        ],
                      ),
                    ),
                  ],
                ),
                if (item.information?.lastSeen != null)
                  VolunteerDetail(
                    s.vLastSeen,
                    dataText(context, item.information!.lastSeen!),
                    icon: Icons.location_on_outlined,
                  ),
                const SizedBox(height: 20),
                VolunteerAction(
                  s.vViewCase,
                  onPressed: () {
                    Navigator.pop(context);
                    _details(item);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.vClose),
                ),
              ],
            ),
          ),
        ),
      );
}
