import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_repository.dart';
import 'guardian_components.dart';
import 'individual_widgets.dart';

class GuidedReportScreen extends StatefulWidget {
  const GuidedReportScreen({super.key, required this.id});
  final String id;
  @override
  State<GuidedReportScreen> createState() => _GuidedReportScreenState();
}

class _GuidedReportScreenState extends State<GuidedReportScreen> {
  Future<MissingCase>? _data;
  MissingCase? _value;
  Map<String, dynamic> _answers = {};
  final _text = TextEditingController();
  bool _busy = false;
  Object? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<MissingCase> _load() async {
    final value = await AppServices.of(context).guardian.missingCase(widget.id);
    _value = value;
    _answers = Map.of(value.report ?? {});
    return value;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _step {
    if (_answers['same_location'] == null) return 0;
    if (_answers['same_location'] == false &&
        (_answers['last_seen_description'] ?? '').isEmpty)
      return 1;
    if ((_answers['clothing'] ?? '').isEmpty) return 2;
    if (_answers['carrying_distinctive'] == null) return 3;
    if (_answers['carrying_distinctive'] == true &&
        (_answers['distinctive_description'] ?? '').isEmpty)
      return 4;
    if (_answers['completed'] != true) return 5;
    return 6;
  }

  Future<void> _answer({bool? choice}) async {
    if (_busy) return;
    final step = _step;
    final s = AppLocalizations.of(context)!;
    if ([1, 2, 4].contains(step) && _text.text.trim().isEmpty) {
      setState(() => _error = const AppFailure('answerRequired'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final next = Map<String, dynamic>.of(_answers);
    try {
      if (step == 0) {
        next['same_location'] = choice;
        if (choice == true) {
          if (!await Geolocator.isLocationServiceEnabled())
            throw const AppFailure('locationRequired');
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied)
            permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever)
            throw const AppFailure('locationRequired');
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );
          next['latitude'] = position.latitude;
          next['longitude'] = position.longitude;
        } else {
          next['latitude'] = null;
          next['longitude'] = null;
        }
      } else if (step == 1) {
        next['last_seen_description'] = _text.text.trim();
      } else if (step == 2) {
        next['clothing'] = _text.text.trim();
      } else if (step == 3) {
        next['carrying_distinctive'] = choice;
        next['distinctive_description'] = '';
      } else if (step == 4) {
        next['distinctive_description'] = _text.text.trim();
      } else if (step == 5) {
        next['additional_information'] = _text.text.trim();
        next['completed'] = true;
      }
      if (!mounted) return;
      final value = await AppServices.of(context).guardian
          .saveGuidedReport(widget.id, next);
      if (mounted)
        setState(() {
          _value = value;
          _answers = Map.of(value.report ?? {});
          _text.clear();
        });
      if (mounted && next['completed'] == true)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.reportSaved)));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _bubble(String text, {bool answer = false}) => Align(
    alignment: answer
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: answer ? const Color(0xFFE4F7F9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final questions = [
      s.sameLocationQuestion,
      s.lastSeenDescription,
      s.clothingQuestion,
      s.distinctiveQuestion,
      s.distinctiveDescription,
      s.additionalQuestion,
    ];
    final required = !_busy && (_value == null || !_value!.reportSubmitted);
    return PopScope(
      canPop: !required,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(s.guidedAssistantRequired)));
        }
      },
      child: FutureBuilder<MissingCase>(
        future: _data,
        builder: (context, state) {
          final value = _value;
          final step = _step;
          return FeaturePage(
            title: s.reportingAssistant,
            children: [
              if (state.hasError)
                ErrorNotice(
                  message: failureMessage(state.error!, s),
                  onRetry: () => setState(() {
                    _data = _load();
                  }),
                )
              else if (value == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text(
                  '${s.activeCase} · ${value.id}',
                  style: const TextStyle(color: AppColors.secondary),
                ),
                const SizedBox(height: 16),
                GuardianPanel(
                  child: Row(
                    children: [
                      IndividualPhoto(id: value.individualId, size: 48),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text('${value.name}\n${s.age}: ${value.age}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _bubble(questions[0]),
                if (_answers['same_location'] != null)
                  _bubble(
                    _answers['same_location'] == true ? s.yes : s.no,
                    answer: true,
                  ),
                if (_answers['same_location'] == true)
                  _bubble(s.locationReady, answer: true),
                if (_answers['same_location'] == false) ...[
                  _bubble(questions[1]),
                  if ((_answers['last_seen_description'] ?? '').isNotEmpty)
                    _bubble(
                      _answers['last_seen_description'] as String,
                      answer: true,
                    ),
                ],
                if (step >= 2) ...[
                  _bubble(questions[2]),
                  if ((_answers['clothing'] ?? '').isNotEmpty)
                    _bubble(_answers['clothing'] as String, answer: true),
                ],
                if (step >= 3) ...[
                  _bubble(questions[3]),
                  if (_answers['carrying_distinctive'] != null)
                    _bubble(
                      _answers['carrying_distinctive'] == true ? s.yes : s.no,
                      answer: true,
                    ),
                ],
                if (step >= 4 && _answers['carrying_distinctive'] == true) ...[
                  _bubble(questions[4]),
                  if ((_answers['distinctive_description'] ?? '').isNotEmpty)
                    _bubble(
                      _answers['distinctive_description'] as String,
                      answer: true,
                    ),
                ],
                if (step >= 5) ...[
                  _bubble(questions[5]),
                  if ((_answers['additional_information'] ?? '').isNotEmpty)
                    _bubble(
                      _answers['additional_information'] as String,
                      answer: true,
                    ),
                ],
                if (_error != null)
                  ErrorNotice(
                    message:
                        _error is AppFailure &&
                            (_error as AppFailure).code == 'locationRequired'
                        ? s.locationRequired
                        : _error is AppFailure &&
                              (_error as AppFailure).code == 'answerRequired'
                        ? s.requiredAnswer
                        : failureMessage(_error!, s),
                  ),
                if (step == 0 || step == 3)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _answer(choice: false),
                          child: Text(s.no),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : () => _answer(choice: true),
                          child: Text(s.yes),
                        ),
                      ),
                    ],
                  )
                else if (step < 6) ...[
                  TextField(
                    controller: _text,
                    enabled: !_busy,
                    maxLines: 3,
                    maxLength: step == 5 ? 2000 : 1000,
                    decoration: InputDecoration(labelText: questions[step]),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => _answer(),
                    child: Text(step == 5 ? s.saveReport : s.continueLabel),
                  ),
                ] else ...[
                  Text(
                    s.reportSaved,
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.viewStatus),
                  ),
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
