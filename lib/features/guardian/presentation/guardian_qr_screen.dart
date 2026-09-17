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

class GuardianQrScreen extends StatefulWidget {
  const GuardianQrScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<GuardianQrScreen> createState() => _GuardianQrScreenState();
}

class _GuardianQrScreenState extends State<GuardianQrScreen> {
  Future<List<MissingCase>>? _data;
  String? _selected;
  GuardianVerification? _code;
  Object? _error;
  bool _busy = false;
  Timer? _expiry;
  int _request = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<List<MissingCase>> _load() async {
    final values = (await AppServices.of(
      context,
    ).guardian.cases()).where((c) => c.verificationEligible).toList();
    if (mounted) {
      _selected = values.any((c) => c.id == _selected)
          ? _selected
          : values.firstOrNull?.id;
    }
    return values;
  }

  void _reload() {
    _request++;
    _expiry?.cancel();
    setState(() {
      _code = null;
      _busy = false;
      _error = null;
      _data = _load();
    });
  }

  Future<void> _generate() async {
    final id = _selected;
    if (id == null || _busy) return;
    final request = ++_request;
    _expiry?.cancel();
    setState(() {
      _busy = true;
      _code = null;
      _error = null;
    });
    try {
      final code = await AppServices.of(context).guardian.verification(id);
      if (!mounted || request != _request) return;
      setState(() => _code = code);
      final remaining = code.expiresAt.difference(DateTime.now());
      _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        if (mounted) setState(() => _code = null);
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
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
    return FutureBuilder<List<MissingCase>>(
      future: _data,
      builder: (context, state) => FeaturePage(
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
          if (state.hasError)
            ErrorNotice(
              message: failureMessage(state.error!, s),
              onRetry: _reload,
            )
          else if (!state.hasData)
            const Center(child: CircularProgressIndicator())
          else if (state.data!.isEmpty)
            GuardianPanel(child: Text(s.noEligibleCases))
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.activeCase),
              items: [
                for (final c in state.data!)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.name} · ${c.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (id) {
                      _expiry?.cancel();
                      setState(() {
                        _selected = id;
                        _code = null;
                        _error = null;
                      });
                    },
            ),
            const SizedBox(height: 24),
            for (final value in state.data!.where((c) => c.id == _selected))
              GuardianPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      value.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${s.age}: ${value.age}'),
                    Text(value.id, textDirection: TextDirection.ltr),
                    const SizedBox(height: 8),
                    Text(caseStatusLabel(value.status, s)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
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
            ],
            if (_error != null)
              ErrorNotice(message: failureMessage(_error!, s)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _generate,
              child: Text(s.refreshCode),
            ),
            if (_busy) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
            Text(s.verificationExplanation, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => showCaseIdentifier(context, _selected!),
              child: Text(s.showCaseIdentifier),
            ),
          ],
        ],
      ),
    );
  }
}
