part of 'volunteer_workspace.dart';

/// Length of the short Guardian-read verification code of a standalone Found
/// Report (server-defined; the internal FR-… report id is never typed).
const verificationCodeLength = 6;

/// Drops separators a Guardian may read aloud or a keyboard may insert
/// (spaces, '#', dashes) and maps Arabic-Indic numerals to ASCII digits.
/// Any other character is kept so that it fails validation.
String normalizeVerificationCode(String value) {
  final out = StringBuffer();
  for (final rune in value.runes) {
    if (rune == 0x20 || rune == 0x23 || rune == 0x2D || rune == 0x09) continue;
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660); // Arabic-Indic ٠..٩
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + rune - 0x06F0); // Eastern Arabic-Indic ۰..۹
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

bool isVerificationCode(String normalized) =>
    normalized.length == verificationCodeLength &&
    normalized.runes.every((r) => r >= 0x30 && r <= 0x39);

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
    const SizedBox(height: 12),
    VolunteerAction(
      s.vManualReview,
      icon: Icons.manage_search,
      secondary: true,
      onPressed: account.active && !_busy
          ? () => _openManual(independent: true)
          : null,
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
            Text(switch (report.foundStatus) {
              FoundStatus.identified => s.vIdentityConfirmed,
              FoundStatus.verifying => s.vAwaitingGuardian,
              FoundStatus.reunited => s.vReunited,
              _ => s.vIdentificationInProgress,
            }),
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
      if (!_canParticipate) return;
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => const VolunteerCapture()),
      );
      if (bytes == null || !mounted) return;
      if (!_canParticipate) return;
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
    _identificationState = IdentificationState.ready;
    _open(VolunteerView.matches);
  });
  VolunteerView _reportDestination(FoundReport report) {
    // The persisted lifecycle, not a cached profile or an AI result, controls
    // continuation. Incomplete identified data must never restart identification.
    if (report.ended) throw StateError('identification-ended');
    switch (report.foundStatus) {
      case FoundStatus.reunited:
        return VolunteerView.reunited;
      case FoundStatus.verifying:
        if (report.matchedPerson == null) throw StateError('report-incomplete');
        return report.verification == null
            ? VolunteerView.verify
            : VolunteerView.verified;
      case FoundStatus.identified:
        if (report.matchedPerson == null) throw StateError('report-incomplete');
        return VolunteerView.contact;
      case FoundStatus.identifying:
        return VolunteerView.matches;
      case null:
        throw StateError('report-state-unavailable');
    }
  }

  void _restoreReport(FoundReport report) {
    final destination = _reportDestination(report);
    _report = report;
    _person = report.matchedPerson;
    _independentReview = false;
    _similarity = null;
    _candidates = [];
    _identificationState = IdentificationState.ready;
    _update(() {
      // Back must not return an already-confirmed report to old identification.
      _stack.removeWhere((page) => page.index >= VolunteerView.finding.index);
      if (_stack.isEmpty) _stack.add(VolunteerView.report);
      _stack.add(destination);
    });
  }

  Future<void> _resumeReport(String id) => _run(() async {
    if (repo is! ApiVolunteerRepository) return;
    final report = await (repo as ApiVolunteerRepository).loadReport(id);
    if (mounted) _restoreReport(report);
  });

  Future<void> _openManual({bool independent = false}) => _run(() async {
    if (!independent && _report?.ended == true) {
      throw StateError('identification-ended');
    }
    if (repo is ApiVolunteerRepository) {
      await (repo as ApiVolunteerRepository).loadProfiles();
    }
    if (mounted) {
      _independentReview = independent;
      if (independent) _manualRequestId = null;
      _open(VolunteerView.manual);
    }
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
      _update(() {
        _candidates = results;
        _identificationState = results.isEmpty
            ? IdentificationState.noReliableCandidate
            : IdentificationState.candidates;
      });
      _replace(VolunteerView.matches);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Radd identification failed: ${error.runtimeType}');
      }
      if (mounted &&
          generation == _searchGeneration &&
          view == VolunteerView.finding) {
        _replace(VolunteerView.matches);
        _update(
          () => _identificationState =
              error is StateError && error.message == 'ai-unavailable'
              ? IdentificationState.unavailable
              : IdentificationState.error,
        );
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
      s.vManualReview,
      secondary: true,
      onPressed: _busy ? null : _openManual,
    ),
    VolunteerAction(
      s.vCancelSearch,
      onPressed: () => _selectTab(2),
      secondary: true,
      icon: Icons.close,
    ),
  ];
  Future<void> _endIdentification() async {
    if (!await _confirm(
          s.vEndIdentification,
          s.vEndIdentificationHint,
          s.vEndIdentification,
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      await (repo as ApiVolunteerRepository).endIdentification(_report!);
      _report = null;
      _person = null;
      _candidates = [];
      if (mounted) _selectTab(2);
    });
  }

  Future<void> _startAi() async {
    if (_report == null || _report!.ended) return;
    _identificationState = IdentificationState.processing;
    _open(VolunteerView.finding);
    unawaited(_loadCandidates(_report!, ++_searchGeneration));
  }

  List<Widget> _matches() => [
    VolunteerAction(
      s.vFindWithAi,
      icon: Icons.person_search_outlined,
      onPressed: _busy || _report?.ended == true ? null : _startAi,
    ),
    VolunteerAction(
      s.vManualReview,
      icon: Icons.manage_search,
      onPressed: _busy || _report?.ended == true ? null : _openManual,
      secondary: true,
    ),
    if (repo is ApiVolunteerRepository && _report?.matchedPerson == null)
      VolunteerAction(
        s.vEndIdentification,
        secondary: true,
        onPressed: _busy ? null : _endIdentification,
      ),
    VolunteerInfo(switch (_identificationState) {
      IdentificationState.ready => s.vAiReady,
      IdentificationState.unavailable => s.vAiUnavailable,
      IdentificationState.error => s.vAiError,
      _ => s.vCandidateHint,
    }, title: s.vPotentialMatches),
    if (_identificationState == IdentificationState.noReliableCandidate)
      VolunteerEmpty(s.vNoResults, s.vManualFallback),
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
  ];
  Future<void> _candidate(RegisteredPerson person, double? similarity) =>
      _run(() async {
        if (similarity != null) _independentReview = false;
        final selected = repo is ApiVolunteerRepository
            ? await (repo as ApiVolunteerRepository).loadProfileDetails(
                person,
                foundReportId: _independentReview ? null : _report?.id,
              )
            : person;
        if (!mounted) return;
        _person = selected;
        _similarity = similarity;
        _open(VolunteerView.matchDetails);
      });

  List<Widget> _manual() {
    final query = _search.text.trim().toLowerCase();
    final people = repo.reviewableProfiles
        .where(
          (p) =>
              (_gender == null || p.gender == _gender) &&
              (p.name.en.toLowerCase().contains(query) ||
                  p.name.ar.contains(query)),
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
      if (people.isEmpty)
        VolunteerEmpty(
          s.vNoResults,
          repo.reviewableProfiles.isEmpty
              ? s.vNoEligibleRegistrations
              : s.vClearFilters,
        ),
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

  Widget _personSummary(RegisteredPerson person, {CaseStatus? status}) =>
      VolunteerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status != null) ...[
              if (_report?.caseId == null &&
                  _report?.foundStatus == FoundStatus.identified)
                VolunteerHeading(s.vIdentityConfirmed)
              else
                StatusChip(status),
              const SizedBox(height: 16),
            ],
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
            if (_associatedCase != null ||
                (!_independentReview && _report?.matchedPerson != null)) ...[
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

  /// No Missing Case behind this report: the fallback identifier is the
  /// report's short Guardian-read verification code, not a case identifier.
  bool get _standaloneVerification =>
      _report?.caseId == null && _associatedCase == null;

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
      if (!_independentReview)
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
      if (_independentReview) _personSummary(person),
      if (!_independentReview) VolunteerInfo(s.vMatchNotice),
      VolunteerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VolunteerHeading(s.vCaseInformation),
            const SizedBox(height: 10),
            if (_associatedCase != null) Text(_associatedCase!.id),
            if (person.gender != null)
              VolunteerDetail(
                s.vGender,
                person.gender == Gender.male ? s.vMale : s.vFemale,
              ),
            if (info?.coordinates != null)
              VolunteerDetail(
                s.vLastSeen,
                '${info!.coordinates!.latitude}, ${info.coordinates!.longitude}',
                ltr: true,
                icon: Icons.location_on_outlined,
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
            if (!_independentReview) ...[
              const Divider(height: 24),
              VolunteerDetail(
                s.vGuardianName,
                dataText(context, person.guardian.name),
              ),
              VolunteerDetail(
                s.vRelationship,
                relationshipText(context, person.guardian.relationship),
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
      if (!_independentReview && !person.confirmationAvailable)
        VolunteerInfo(s.vStandalonePending),
      if (!_independentReview && person.confirmationAvailable)
        VolunteerAction(
          _associatedCase == null ? s.vConfirmIdentity : s.vConfirmMatch,
          icon: Icons.check_circle_outline,
          onPressed:
              _busy ||
                  _report == null ||
                  _report!.ended ||
                  _report!.matchedPerson != null
              ? null
              : _confirmSelected,
        ),
      if (_independentReview)
        VolunteerAction(
          s.vConfirmIdentity,
          icon: Icons.check_circle_outline,
          onPressed: _busy ? null : _confirmSelected,
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
      if (_independentReview) {
        if (repo is! ApiVolunteerRepository) return;
        _manualRequestId ??= List.generate(
          24,
          (_) => math.Random.secure()
              .nextInt(256)
              .toRadixString(16)
              .padLeft(2, '0'),
        ).join();
        _report = await (repo as ApiVolunteerRepository).confirmManualIdentity(
          _person!.id,
          _manualRequestId!,
        );
        _independentReview = false;
      } else {
        await repo.confirmMatch(account, _report!, _person!);
      }
      if (mounted) {
        if (repo is ApiVolunteerRepository) {
          _restoreReport(_report!);
        } else {
          _replace(VolunteerView.contact);
        }
      }
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
              // Standalone: the Guardian reads a short numeric code, so
              // offer the number pad; a linked Missing Case keeps its
              // alphanumeric case identifier.
              keyboardType: _standaloneVerification
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: _standaloneVerification
                    ? s.vFoundReportIdentifier
                    : s.vGuardianIdentifier,
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return s.vRequired;
                if (_standaloneVerification &&
                    !isVerificationCode(normalizeVerificationCode(value))) {
                  return s.vVerificationCodeFormat;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              _standaloneVerification
                  ? s.vFoundIdentifierHelp
                  : s.vExactIdentifier,
            ),
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
                  _standaloneVerification
                      ? normalizeVerificationCode(_identifier.text)
                      : _identifier.text,
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
    if (_report!.matchedPerson != null) _personSummary(_report!.matchedPerson!),
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
    if (_report!.matchedPerson != null) _personSummary(_report!.matchedPerson!),
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
            relationshipText(
              context,
              _report!.matchedPerson!.guardian.relationship,
            ),
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
      _person = null;
      _candidates = [];
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
    if (_report!.matchedPerson != null) _personSummary(_report!.matchedPerson!),
    VolunteerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VolunteerDetail(
            s.vHandoverTime,
            timeText(context, _report!.handedOverAt!),
            icon: Icons.schedule,
          ),
          if (_report!.matchedPerson != null)
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
          if (_report!.verification != null)
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
