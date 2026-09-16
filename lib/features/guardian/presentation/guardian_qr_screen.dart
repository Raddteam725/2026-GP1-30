import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';

Future<void> showCaseIdentifier(BuildContext context, String id) async {
  final s = AppLocalizations.of(context)!;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.caseIdentifier,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GuardianPanel(
              child: SelectableText(
                id,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(s.caseIdentifierHint, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.close),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Account-level QR: this Guardian account has exactly one verification code,
/// independent of any particular case. The list of cases currently awaiting
/// verification below is informational only -- it never selects or scopes
/// the code above, and the code still displays even with zero cases.
class GuardianQrScreen extends StatefulWidget {
  const GuardianQrScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<GuardianQrScreen> createState() => _GuardianQrScreenState();
}

class _GuardianQrScreenState extends State<GuardianQrScreen> {
  Future<List<MissingCase>>? _cases;
  GuardianVerification? _code;
  Object? _codeError;
  bool _busy = false;
  Timer? _expiry;
  int _request = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cases ??= _loadCases();
    if (_code == null && _codeError == null && !_busy) _generate();
  }

  Future<List<MissingCase>> _loadCases() async => (await AppServices.of(
    context,
  ).guardian.cases()).where((c) => c.verificationEligible).toList();

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
      final remaining = code.expiresAt.difference(DateTime.now());
      _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        if (mounted) setState(() => _code = null);
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _codeError = e);
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FeaturePage(
      title: s.qrCode,
      subtitle: s.verificationExplanation,
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: s.retry,
          icon: const Icon(Icons.refresh),
        ),
      ],
      bottomNavigationBar: widget.embedded
          ? null
          : const GuardianNavigation(selected: 2),
      children: [
        Text(
          s.guardianVerification,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (_code case final code?) ...[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: AspectRatio(
                aspectRatio: 1,
                child: QrImageView(
                  data: code.payload,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.verificationExpires}: ${caseDate(context, code.expiresAt)}',
            textAlign: TextAlign.center,
          ),
        ] else if (_busy)
          const Center(child: CircularProgressIndicator())
        else if (_codeError != null)
          ErrorNotice(
            message: failureMessage(_codeError!, s),
            onRetry: _generate,
          ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _generate,
            child: Text(s.refreshCode),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          s.casesAwaitingVerification,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
              return const Center(child: CircularProgressIndicator());
            }
            if (state.data!.isEmpty) {
              return GuardianPanel(child: Text(s.noEligibleCases));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final value in state.data!) ...[
                  GuardianPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          value.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${s.age}: ${value.age}'),
                        Text(value.id, textDirection: TextDirection.ltr),
                        const SizedBox(height: 4),
                        Text(caseStatusLabel(value.status, s)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () =>
                              showCaseIdentifier(context, value.id),
                          child: Text(s.showCaseIdentifier),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
