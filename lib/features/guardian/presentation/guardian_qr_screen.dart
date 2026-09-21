import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/guardian_push_service.dart';
import '../data/coalesced_refresh.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../onboarding/presentation/widgets/onboarding_layout.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';
import 'individual_widgets.dart';

/// Case Identifier: the case-specific alternative when the QR cannot be
/// displayed or scanned. The Volunteer compares it with the identifier of
/// their own current case; the identifier alone never proves identity.
Future<void> showCaseIdentifier(BuildContext context, MissingCase value) async {
  final s = AppLocalizations.of(context)!;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.caseIdentifier,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Center(child: IndividualPhoto(id: value.individualId, size: 88)),
            const SizedBox(height: 12),
            Text(
              value.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    s.activeCaseIdentifier.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: mutedText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    caseDisplayId(value.id),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.caseIdentifierInstruction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.caseIdentifierUsage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: mutedText),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8EFFB),
                foregroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(s.close),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One Guardian-ACCOUNT verification QR (not one per case): the Volunteer's
/// own current case supplies the case context when they scan it, and the
/// backend checks that this Guardian is the one associated with that case.
/// The active-case selector on this screen only chooses which case's
/// context card and Case Identifier are shown -- it never changes the QR,
/// and the QR is shown even when the Guardian has no active case at all.
/// The credential is short-lived and single-use; it is regenerated
/// automatically at expiry while this screen stays open.
class GuardianQrScreen extends StatefulWidget {
  const GuardianQrScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<GuardianQrScreen> createState() => _GuardianQrScreenState();
}

class _GuardianQrScreenState extends State<GuardianQrScreen> {
  Future<List<MissingCase>>? _cases;
  List<MissingCase> _active = const [];
  String? _selectedId;
  GuardianVerification? _code;
  Object? _codeError;
  bool _busy = false;
  Timer? _expiry;
  int _request = 0;
  int _caseRequest = 0;
  @override
  void initState() {
    super.initState();
    GuardianPushRefresh.instance.addListener(_recoverCases);
  }

  final _eventRefresh = CoalescedRefresh();
  Future<void> _recoverCases() => _eventRefresh.run(_recoverCasesOnce);
  Future<void> _recoverCasesOnce() async {
    if (!mounted) return;
    try {
      await _loadCases();
    } catch (error) {
      assert(() {
        debugPrint('Radd Guardian QR refresh failed (${error.runtimeType})');
        return true;
      }());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cases ??= _loadCases();
    if (_code == null && _codeError == null && !_busy) _generate();
  }

  Future<List<MissingCase>> _loadCases() async {
    final generation = ++_caseRequest;
    final all = await AppServices.of(context).guardian.cases();
    // Most relevant first: the case currently awaiting this Guardian's
    // verification, then the furthest-progressed, then the most recent.
    final active = all.where((c) => c.active).toList()
      ..sort((a, b) {
        final stage = caseStages
            .indexOf(b.status)
            .compareTo(caseStages.indexOf(a.status));
        if (stage != 0) return stage;
        return (b.updatedAt ?? DateTime(0)).compareTo(
          a.updatedAt ?? DateTime(0),
        );
      });
    if (mounted && generation == _caseRequest) {
      setState(() {
        _active = active;
        if (!active.any((c) => c.id == _selectedId)) {
          _selectedId = active.isEmpty ? null : active.first.id;
        }
      });
    }
    return active;
  }

  MissingCase? get _selected {
    for (final c in _active) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  void _reload() {
    setState(() {
      _cases = _loadCases();
    });
    _generate();
  }

  Future<void> _generate() async {
    final request = ++_request;
    _expiry?.cancel();
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final code = await AppServices.of(context).guardian.accountVerification();
      if (!mounted || request != _request) return;
      setState(() => _code = code);
      // Automatic regeneration at expiry: the Guardian never has to notice
      // an expired code while this screen is open.
      final remaining = code.expiresAt.difference(DateTime.now());
      _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        if (mounted) _generate();
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _codeError = e;
          _code = null;
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    GuardianPushRefresh.instance.removeListener(_recoverCases);
    _expiry?.cancel();
    super.dispose();
  }

  Future<void> _pickCase() async {
    final s = AppLocalizations.of(context)!;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                s.selectActiveCase,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            for (final value in _active)
              ListTile(
                leading: IndividualPhoto(id: value.individualId, size: 44),
                title: Text(
                  value.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                subtitle: Text(
                  caseDisplayId(value.id),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
                trailing: value.id == _selectedId
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                selected: value.id == _selectedId,
                selectedTileColor: const Color(0xFFE8EFFB),
                onTap: () => Navigator.pop(context, value.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _selectedId = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final selected = _selected;
    return FeaturePage(
      title: s.qrCode,
      showAppBar: false,
      bottomNavigationBar: widget.embedded
          ? null
          : const GuardianNavigation(selected: 2),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.qrCode,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.qrSubtitle,
                    style: const TextStyle(
                      color: mutedText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: s.retry,
              onPressed: _reload,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<MissingCase>>(
          future: _cases,
          builder: (context, state) {
            if (state.hasError) {
              return ErrorNotice(
                message: failureMessage(state.error!, s),
                onRetry: _reload,
              );
            }
            if (!state.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (selected == null) {
              return _note(Icons.info_outline, s.noActiveCaseQrNote);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _selector(s, selected),
                const SizedBox(height: 16),
                _caseCard(s, selected),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _qrCard(s),
        const SizedBox(height: 16),
        _note(
          Icons.verified_user_outlined,
          selected == null ? s.qrVerifiesAccountNoCase : s.qrVerifiesAccount,
        ),
        const SizedBox(height: 24),
        Text(
          s.cannotDisplayQr,
          textAlign: TextAlign.center,
          style: const TextStyle(color: mutedText, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Center(
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8EFFB),
              foregroundColor: AppColors.primary,
              disabledBackgroundColor: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            onPressed: selected == null
                ? null
                : () => showCaseIdentifier(context, selected),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(
              s.showCaseIdentifier,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _selector(AppLocalizations s, MissingCase selected) => GuardianPanel(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: _active.length > 1 ? _pickCase : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.selectActiveCase.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: mutedText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(dimension: 7),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          selected.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CaseIdChip(id: selected.id),
                    ],
                  ),
                ],
              ),
            ),
            if (_active.length > 1)
              const Icon(Icons.unfold_more, color: mutedText),
          ],
        ),
      ),
    ),
  );

  Widget _caseCard(AppLocalizations s, MissingCase selected) => GuardianPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IndividualPhoto(id: selected.individualId, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      text: '${s.caseId}: ',
                      style: const TextStyle(fontSize: 13, color: mutedText),
                      children: [
                        TextSpan(
                          text: caseDisplayIdIsolated(selected.id),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              s.ageYears('${selected.age}'),
              style: const TextStyle(fontSize: 12, color: mutedText),
            ),
          ],
        ),
        const SizedBox(height: 14),
        StatusChip(status: selected.status, withStageNumber: true),
      ],
    ),
  );

  Widget _qrCard(AppLocalizations s) {
    final code = _code;
    return GuardianPanel(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: SizedBox.square(
              dimension: 220,
              child: code != null
                  ? QrImageView(
                      data: code.payload,
                      size: 220,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.primary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.primary,
                      ),
                      embeddedImage: const AssetImage(
                        OnboardingLayout.logoAsset,
                      ),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(44, 44),
                      ),
                    )
                  : _busy
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(
                      child: Icon(
                        Icons.qr_code_2,
                        size: 64,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.guardianVerification,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.scanInstruction,
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedText, fontSize: 13, height: 1.4),
          ),
          if (code != null) ...[
            const SizedBox(height: 8),
            Text(
              '${s.verificationExpires}: ${caseDate(context, code.expiresAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedText, fontSize: 11),
            ),
          ] else if (_busy) ...[
            const SizedBox(height: 8),
            Text(
              s.qrRefreshing,
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedText, fontSize: 11),
            ),
          ] else if (_codeError != null)
            ErrorNotice(
              message: failureMessage(_codeError!, s),
              onRetry: _generate,
            ),
        ],
      ),
    );
  }

  Widget _note(IconData icon, String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE6F6F8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: .15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45)),
        ),
      ],
    ),
  );
}
