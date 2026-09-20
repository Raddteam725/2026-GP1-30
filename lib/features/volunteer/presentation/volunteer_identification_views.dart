part of 'volunteer_workspace.dart';

extension _VolunteerIdentificationViews on _VolunteerWorkspaceState {
  List<Widget> _reportView() => [
    VolunteerInfo(s.vCaptureNotice),
    const SizedBox(height: 8),
    VolunteerCard(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const CircleAvatar(
            radius: 46,
            backgroundColor: Color(0xFFE8EDFF),
            child: Icon(
              Icons.photo_camera_outlined,
              size: 46,
              color: volunteerNavy,
            ),
          ),
          const SizedBox(height: 28),
          VolunteerHeading(s.vPositionFace),
          const SizedBox(height: 10),
          Text(s.vPhotoHint, textAlign: TextAlign.center),
          const SizedBox(height: 32),
        ],
      ),
    ),
    const SizedBox(height: 12),
    VolunteerAction(
      s.vOpenCamera,
      icon: Icons.photo_camera_outlined,
      onPressed: account.active && !_busy ? _openCamera : null,
    ),
    const SizedBox(height: 16),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 18, color: Color(0xFF747783)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            s.vPhotoPurpose,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF434652),
            ),
          ),
        ),
      ],
    ),
    if (_pendingCapture != null)
      VolunteerAction(s.vTryAgain, onPressed: _busy ? null : _submitCapture),
    for (final report in repo.foundReports)
      VolunteerCard(
        onTap: () => _resumeReport(report.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VolunteerHeading(report.id),
            if (report.status != null) StatusChip(report.status!),
            Text(
              report.createdAt == null
                  ? ''
                  : timeText(context, report.createdAt!),
            ),
            Text(s.vContinueReport),
          ],
        ),
      ),
  ];
  Future<void> _openCamera() async {
    if (repo is ApiVolunteerRepository) {
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => const VolunteerCapture()),
      );
      if (bytes == null || !mounted) return;
      _pendingCapture = bytes;
      _captureRequestId = List.generate(
        24,
        (_) =>
            math.Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _submitCapture();
      return;
    }
    if (!repo.isPreview) return;
    final capture = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VolunteerHeading(s.vPreviewCamera),
              const SizedBox(height: 16),
              Text(s.vPreviewCameraHint),
              const SizedBox(height: 20),
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: volunteerInk,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.center_focus_strong,
                  color: Color(0xFF5AD7E6),
                  size: 100,
                ),
              ),
              const SizedBox(height: 20),
              VolunteerAction(
                s.vPreviewCapture,
                icon: Icons.camera_alt_outlined,
                onPressed: () => Navigator.pop(context, true),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.vCancel),
              ),
            ],
          ),
        ),
      ),
    );
    if (capture != true || !mounted) return;
    await _run(() async {
      _report = await repo.submitFound(account);
      if (!mounted) return;
      _candidates = [];
      _person = null;
      _similarity = null;
      _open(VolunteerView.finding);
      final generation = ++_searchGeneration;
      final report = _report!;
      // Deliberate mock loading state; no AI service or photo upload occurs.
      unawaited(_loadCandidates(report, generation));
    });
  }

  Future<void> _submitCapture() => _run(() async {
    _report = await repo.submitFound(
      account,
      photo: _pendingCapture,
      requestId: _captureRequestId,
    );
    _pendingCapture = null;
    _captureRequestId = null;
    if (!mounted) return;
    _candidates = [];
    _person = null;
    _similarity = null;
    _aiUnavailable = false;
    _open(VolunteerView.finding);
    unawaited(_loadCandidates(_report!, ++_searchGeneration));
  });
  Future<void> _resumeReport(String id) => _run(() async {
    if (repo is! ApiVolunteerRepository) return;
    _report = await (repo as ApiVolunteerRepository).loadReport(id);
    _person = _report!.matchedPerson;
    _similarity = null;
    if (!mounted) return;
    if (_report!.status == CaseStatus.reunited) {
      _open(VolunteerView.reunited);
    } else if (_report!.verification != null) {
      _open(VolunteerView.verified);
    } else if (_report!.matchedPerson != null) {
      _open(VolunteerView.contact);
    } else {
      _candidates = [];
      _aiUnavailable = true;
      _open(VolunteerView.matches);
    }
  });
  Future<void> _openManual() => _run(() async {
    if (repo is ApiVolunteerRepository) {
      await (repo as ApiVolunteerRepository).loadProfiles();
    }
    if (mounted) _open(VolunteerView.manual);
  });
  Widget _foundImage({required double width, required double height}) {
    final bytes = _report!.photoBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    if (repo.isPreview) {
      return Image.asset(
        _report!.photo,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: const Icon(Icons.person_outline),
    );
  }

  Future<void> _loadCandidates(FoundReport report, int generation) async {
    try {
      if (repo.isPreview) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
      final results = await repo.findMatches(report);
      if (!mounted ||
          generation != _searchGeneration ||
          view != VolunteerView.finding) {
        return;
      }
      _update(() => _candidates = results);
      _replace(VolunteerView.matches);
    } catch (_) {
      if (mounted && generation == _searchGeneration) {
        _replace(VolunteerView.matches);
        _update(() => _aiUnavailable = true);
        _message(s.vAiUnavailable);
      }
    }
  }

  List<Widget> _finding() => [
    const SizedBox(height: 36),
    Center(
      child: SizedBox.square(
        dimension: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFB5D9DD)),
              ),
            ),
            const SizedBox.square(
              dimension: 220,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: volunteerTeal,
              ),
            ),
            ClipOval(child: _foundImage(width: 174, height: 174)),
          ],
        ),
      ),
    ),
    const SizedBox(height: 40),
    Center(child: VolunteerHeading(s.vSearchingProfiles, large: true)),
    const SizedBox(height: 12),
    Text(s.vMatchingHint, textAlign: TextAlign.center),
    const SizedBox(height: 24),
    const LinearProgressIndicator(color: volunteerTeal),
    const SizedBox(height: 32),
    VolunteerAction(
      s.vCancelSearch,
      onPressed: () => _selectTab(2),
      secondary: true,
      icon: Icons.close,
    ),
  ];
  List<Widget> _matches() => [
    VolunteerInfo(
      _aiUnavailable ? s.vAiUnavailable : s.vCandidateHint,
      title: s.vPotentialMatches,
    ),
    if (_candidates.isEmpty) VolunteerEmpty(s.vNoResults, s.vManualFallback),
    for (final candidate in _candidates)
      VolunteerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                VolunteerChip(s.vPotentialMatch),
                if (candidate.similarity != null)
                  VolunteerChip(
                    s.vSimilarityValue(
                      numberText(context, candidate.similarity! * 100),
                    ),
                  ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                PersonPhoto(candidate.person),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VolunteerHeading(
                        dataText(context, candidate.person.name),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${s.vAgeValue(numberText(context, candidate.person.age))} · ${candidate.person.gender == Gender.male ? s.vMale : s.vFemale}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            VolunteerAction(
              s.vViewDetails,
              onPressed: () =>
                  _candidate(candidate.person, candidate.similarity),
              secondary: candidate != _candidates.first,
            ),
          ],
        ),
      ),
    VolunteerInfo(s.vManualFallback),
    VolunteerAction(
      s.vManualReview,
      icon: Icons.manage_search,
      onPressed: _busy ? null : _openManual,
      secondary: true,
    ),
  ];
  void _candidate(RegisteredPerson person, double? similarity) {
    _person = person;
    _similarity = similarity;
    _open(VolunteerView.matchDetails);
  }

  List<Widget> _manual() {
    final query = _search.text.trim().toLowerCase();
    final people = repo.reviewableProfiles
        .where(
          (p) =>
              (_gender == null || p.gender == _gender) &&
              (p.name.en.toLowerCase().contains(query) ||
                  p.name.ar.contains(query)) &&
              (repo.caseForPerson(p.id)?.joinable ?? true),
        )
        .toList();
    return [
      TextField(
        controller: _search,
        onChanged: (_) => _refresh(),
        decoration: InputDecoration(
          labelText: s.vSearchName,
          prefixIcon: const Icon(Icons.search, color: volunteerTeal),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final gender in [null, Gender.male, Gender.female])
            ChoiceChip(
              label: Text(
                gender == null
                    ? s.vAll
                    : gender == Gender.male
                    ? s.vMale
                    : s.vFemale,
              ),
              selected: _gender == gender,
              onSelected: (_) => _update(() => _gender = gender),
            ),
          TextButton(
            onPressed: () => _update(() {
              _gender = null;
              _search.clear();
            }),
            child: Text(s.vClearFilters),
          ),
        ],
      ),
      const SizedBox(height: 20),
      VolunteerHeading(s.vRegisteredIndividuals),
      const SizedBox(height: 16),
      if (people.isEmpty) VolunteerEmpty(s.vNoResults, s.vClearFilters),
      for (final person in people)
        VolunteerCard(
          child: Column(
            children: [
              Row(
                children: [
                  PersonPhoto(person),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VolunteerHeading(dataText(context, person.name)),
                        const SizedBox(height: 8),
                        Text(
                          '${s.vAgeValue(numberText(context, person.age))} · ${person.gender == Gender.male ? s.vMale : s.vFemale}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              VolunteerAction(
                s.vViewDetails,
                onPressed: () => _candidate(person, null),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _personSummary(
    RegisteredPerson person, {
    CaseStatus? status,
  }) => VolunteerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status != null) ...[StatusChip(status), const SizedBox(height: 16)],
        Row(
          children: [
            PersonPhoto(person),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VolunteerHeading(dataText(context, person.name)),
                  const SizedBox(height: 6),
                  Text(s.vAgeValue(numberText(context, person.age))),
                  const SizedBox(height: 6),
                  Text(person.gender == Gender.male ? s.vMale : s.vFemale),
                ],
              ),
            ),
          ],
        ),
        if (_associatedCase != null || _report?.matchedPerson != null) ...[
          const Divider(height: 24),
          Text(
            _associatedCase?.id ?? _report!.id,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: volunteerNavy,
            ),
          ),
        ],
      ],
    ),
  );
  VolunteerCase? get _associatedCase {
    final person = _person ?? _report?.matchedPerson;
    if (person == null) return null;
    for (final item in repo.cases) {
      if (item.person.id == person.id) return item;
    }
    return null;
  }

  List<Widget> _matchDetails() {
    final person = _person!;
    final info =
        person.information ?? repo.caseForPerson(person.id)?.information;
    return [
      if (_similarity != null)
        VolunteerCard(
          color: const Color(0xFFC5F8FC),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: volunteerTeal),
              const SizedBox(width: 12),
              Expanded(
                child: VolunteerHeading(
                  s.vSimilarityValue(numberText(context, _similarity! * 100)),
                  color: volunteerTeal,
                ),
              ),
            ],
          ),
        ),
      VolunteerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VolunteerHeading(s.vCompare),
            const Divider(height: 26),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.vFoundIndividual,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _foundImage(width: width, height: 160),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.vRegisteredProfile,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          PersonPhoto(person, size: width, height: 160),
                          const SizedBox(height: 10),
                          Text(
                            dataText(context, person.name),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(s.vAgeValue(numberText(context, person.age))),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      VolunteerInfo(s.vMatchNotice),
      VolunteerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VolunteerHeading(s.vCaseInformation),
            const SizedBox(height: 10),
            if (_associatedCase != null) Text(_associatedCase!.id),
            VolunteerDetail(
              s.vGender,
              person.gender == Gender.male ? s.vMale : s.vFemale,
            ),
            if (info?.lastSeen != null)
              VolunteerDetail(
                s.vLastSeen,
                dataText(context, info!.lastSeen!),
                icon: Icons.location_on_outlined,
              ),
            if (info?.clothing != null)
              VolunteerDetail(
                s.vClothing,
                dataText(context, info!.clothing!),
                icon: Icons.checkroom,
              ),
            if (info?.distinctive != null)
              VolunteerDetail(
                s.vDistinctive,
                dataText(context, info!.distinctive!),
                icon: Icons.backpack_outlined,
              ),
            if (info?.additional != null)
              VolunteerDetail(
                s.vAdditional,
                dataText(context, info!.additional!),
                icon: Icons.info_outline,
              ),
            if (repo.isPreview) ...[
              const Divider(height: 24),
              VolunteerDetail(
                s.vGuardianName,
                dataText(context, person.guardian.name),
              ),
              VolunteerDetail(
                s.vRelationship,
                dataText(context, person.guardian.relationship),
              ),
              if (person.guardian.phone != null)
                VolunteerDetail(
                  s.vRegisteredContact,
                  person.guardian.phone!,
                  ltr: true,
                ),
            ],
          ],
        ),
      ),
      VolunteerAction(
        s.vConfirmMatch,
        icon: Icons.check_circle_outline,
        onPressed: _busy || _report!.matchedPerson != null
            ? null
            : _confirmSelected,
      ),
      const SizedBox(height: 12),
      VolunteerAction(
        s.vBackResults,
        onPressed: _back,
        secondary: true,
        icon: Icons.arrow_back,
      ),
    ];
  }

  Future<void> _confirmSelected() async {
    if (!await _confirm(
          s.vConfirmMatchQuestion,
          '${dataText(context, _person!.name)}\n\n${s.vConfirmMatchHint}',
          s.vConfirmMatch,
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await repo.confirmMatch(account, _report!, _person!);
      if (mounted) _replace(VolunteerView.contact);
    });
  }

  List<Widget> _contact() {
    final person = _report!.matchedPerson!, guardian = person.guardian;
    return [
      _personSummary(person, status: _report!.status),
      VolunteerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VolunteerHeading(s.vGuardianDetails, color: volunteerNavy),
            const Divider(height: 28),
            VolunteerCard(
              color: volunteerTint,
              child: VolunteerDetail(
                s.vGuardianName,
                dataText(context, guardian.name),
              ),
            ),
            VolunteerCard(
              color: volunteerTint,
              child: VolunteerDetail(
                s.vRelationship,
                dataText(context, guardian.relationship),
              ),
            ),
            if (guardian.phone != null)
              VolunteerCard(
                color: volunteerTint,
                child: VolunteerDetail(
                  s.vRegisteredContact,
                  guardian.phone!,
                  icon: Icons.phone_outlined,
                  ltr: true,
                ),
              ),
          ],
        ),
      ),
      VolunteerAction(
        s.vContactGuardian,
        icon: Icons.call,
        onPressed: guardian.phone == null
            ? null
            : () async {
                if (repo.isPreview) {
                  _message(s.vPreviewCall);
                  return;
                }
                final opened = await launchUrl(
                  Uri(scheme: 'tel', path: guardian.phone),
                );
                if (!opened && mounted) _message(s.vActionFailed);
              },
      ),
      const SizedBox(height: 12),
      VolunteerAction(
        s.vProceedVerification,
        icon: Icons.fact_check_outlined,
        secondary: true,
        onPressed: _busy
            ? null
            : () => _run(() async {
                await repo.beginVerification(account, _report!);
                if (mounted) _open(VolunteerView.verify);
              }),
      ),
    ];
  }

  List<Widget> _verify() => [
    Text(
      s.vScanInstruction,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: volunteerInk,
      ),
    ),
    const SizedBox(height: 10),
    Text(s.vScanHint, textAlign: TextAlign.center),
    const SizedBox(height: 22),
    Container(
      height: 300,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF192A42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF5AD7E6), width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.qr_code_scanner,
          size: 100,
          color: Color(0xFF5AD7E6),
        ),
      ),
    ),
    const SizedBox(height: 22),
    VolunteerAction(
      s.vScanCode,
      icon: Icons.qr_code_scanner,
      onPressed: _busy ? null : _scanPreview,
    ),
    const SizedBox(height: 24),
    Text(s.vUnableScan, textAlign: TextAlign.center),
    const SizedBox(height: 12),
    VolunteerAction(
      s.vUseIdentifier,
      icon: Icons.pin_outlined,
      secondary: true,
      onPressed: () {
        _identifier.clear();
        _authenticatedShown = false;
        _open(VolunteerView.identifier);
      },
    ),
  ];
  Future<void> _scanPreview() async {
    if (repo is ApiVolunteerRepository) {
      final payload = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const VolunteerQrCapture()),
      );
      if (payload != null && mounted) {
        await _verification(VerificationMethod.qr, payload);
      }
      return;
    }
    if (!repo.isPreview) return;
    final valid = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.vPreviewQr),
        content: Text(s.vPreviewQrHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.vPreviewInvalid),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.vPreviewValid),
          ),
        ],
      ),
    );
    if (valid == null || !mounted) return;
    final id = _associatedCase?.id ?? _report!.id;
    await _verification(
      VerificationMethod.qr,
      valid
          ? 'preview-qr:$id:${_report!.matchedPerson!.guardian.id}'
          : 'preview-invalid',
    );
  }

  List<Widget> _identifierView() => [
    VolunteerInfo(s.vIdentifierHelp),
    _personSummary(_report!.matchedPerson!, status: _report!.status),
    VolunteerCard(
      child: Form(
        key: _identifierForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _identifier,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: s.vGuardianIdentifier,
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? s.vRequired : null,
            ),
            const SizedBox(height: 16),
            Text(s.vExactIdentifier),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                s.vAuthenticatedAccount,
                style: const TextStyle(fontSize: 13),
              ),
              value: _authenticatedShown,
              onChanged: (value) =>
                  _update(() => _authenticatedShown = value ?? false),
            ),
          ],
        ),
      ),
    ),
    VolunteerAction(
      s.vVerify,
      icon: Icons.verified_user_outlined,
      onPressed: _busy || !_authenticatedShown
          ? null
          : () {
              if (_identifierForm.currentState!.validate()) {
                _verification(
                  VerificationMethod.caseIdentifier,
                  _identifier.text,
                );
              }
            },
    ),
  ];
  Future<void> _verification(VerificationMethod method, String value) =>
      _run(() async {
        final valid = await repo.verify(
          account,
          _report!,
          method,
          value,
          authenticatedAccountShown: _authenticatedShown,
        );
        if (mounted) {
          _replace(
            valid ? VolunteerView.verified : VolunteerView.verificationFailed,
          );
        }
      });
  Widget _resultIcon(bool success) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (success ? volunteerTeal : Colors.red).withValues(alpha: .08),
      ),
      child: CircleAvatar(
        radius: 44,
        backgroundColor: success ? volunteerTeal : const Color(0xFFFFE3E3),
        child: Icon(
          success ? Icons.check : Icons.gpp_bad_outlined,
          size: 48,
          color: success ? Colors.white : Colors.red.shade700,
        ),
      ),
    ),
  );
  List<Widget> _failed() => [
    _resultIcon(false),
    Center(child: VolunteerHeading(s.vVerificationFailed, large: true)),
    const SizedBox(height: 16),
    Text(s.vVerificationMismatch, textAlign: TextAlign.center),
    const SizedBox(height: 24),
    _personSummary(_report!.matchedPerson!, status: _report!.status),
    VolunteerInfo(
      s.vNoHandover,
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFF996A00),
    ),
    VolunteerAction(
      s.vTryAgain,
      icon: Icons.qr_code_scanner,
      onPressed: () => _replace(VolunteerView.verify),
    ),
    const SizedBox(height: 12),
    VolunteerAction(
      s.vUseIdentifier,
      secondary: true,
      icon: Icons.pin_outlined,
      onPressed: () {
        _identifier.clear();
        _authenticatedShown = false;
        _replace(VolunteerView.identifier);
      },
    ),
  ];
  List<Widget> _verified() => [
    _resultIcon(true),
    Center(child: VolunteerHeading(s.vVerificationSuccess, large: true)),
    const SizedBox(height: 12),
    Text(s.vAccountCaseVerified, textAlign: TextAlign.center),
    const SizedBox(height: 24),
    _personSummary(_report!.matchedPerson!),
    VolunteerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VolunteerDetail(
            s.vGuardianName,
            dataText(context, _report!.matchedPerson!.guardian.name),
            icon: Icons.person_outline,
          ),
          VolunteerDetail(
            s.vVerifiedTime,
            timeText(context, _report!.verification!.at),
            icon: Icons.schedule,
          ),
          VolunteerDetail(
            s.vVerificationMethod,
            _report!.verification!.method == VerificationMethod.qr
                ? s.vQrMethod
                : s.vIdentifierMethod,
            icon: Icons.verified_user_outlined,
          ),
        ],
      ),
    ),
    VolunteerAction(
      s.vContinueHandover,
      icon: Icons.arrow_forward,
      onPressed: () => _open(VolunteerView.handover),
    ),
  ];
  List<Widget> _handover() => [
    _personSummary(_report!.matchedPerson!),
    VolunteerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VolunteerChip(s.vGuardianVerified, color: volunteerGreen, dot: true),
          const SizedBox(height: 12),
          VolunteerDetail(
            s.vGuardianName,
            dataText(context, _report!.matchedPerson!.guardian.name),
          ),
          VolunteerDetail(
            s.vRelationship,
            dataText(context, _report!.matchedPerson!.guardian.relationship),
          ),
          VolunteerDetail(s.vVolunteerId, account.volunteerId),
        ],
      ),
    ),
    VolunteerInfo(s.vHandoverHint),
    VolunteerAction(
      s.vConfirmHandover,
      icon: Icons.family_restroom,
      onPressed:
          _busy ||
              _report!.verification == null ||
              _report!.status != CaseStatus.awaitingGuardianVerification
          ? null
          : _confirmHandover,
    ),
  ];
  Future<void> _confirmHandover() async {
    if (!await _confirm(
          s.vHandoverQuestion,
          s.vHandoverConfirmHint,
          s.vConfirmHandover,
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await repo.handover(account, _report!);
      if (mounted) {
        _update(
          () => _stack
            ..clear()
            ..add(VolunteerView.home)
            ..add(VolunteerView.reunited),
        );
      }
    });
  }

  List<Widget> _reunited() => [
    _resultIcon(true),
    Center(child: VolunteerHeading(s.vCompleted, large: true)),
    const SizedBox(height: 12),
    Text(s.vCompletedHint, textAlign: TextAlign.center),
    const SizedBox(height: 20),
    Center(child: StatusChip(CaseStatus.reunited)),
    const SizedBox(height: 32),
    _personSummary(_report!.matchedPerson!),
    VolunteerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VolunteerDetail(
            s.vHandoverTime,
            timeText(context, _report!.handedOverAt!),
            icon: Icons.schedule,
          ),
          VolunteerDetail(
            s.vGuardianName,
            dataText(context, _report!.matchedPerson!.guardian.name),
            icon: Icons.family_restroom,
          ),
          VolunteerDetail(
            s.vConfirmedBy,
            '${dataText(context, account.name)} · ${account.volunteerId}',
            icon: Icons.badge_outlined,
          ),
          VolunteerDetail(
            s.vVerificationMethod,
            _report!.verification!.method == VerificationMethod.qr
                ? s.vQrMethod
                : s.vIdentifierMethod,
          ),
        ],
      ),
    ),
    VolunteerAction(
      s.vDone,
      icon: Icons.arrow_forward,
      onPressed: () => _selectTab(0),
    ),
  ];
}
