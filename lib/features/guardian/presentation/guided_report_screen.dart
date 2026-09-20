import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';
import 'individual_widgets.dart';

/// The Reporting Assistant: a structured, one-time guided case-details
/// workflow presented as a conversation (per the approved design) -- not a
/// general chatbot and not a permanent chat. It opens automatically after a
/// case is created and must be completed before leaving; every answer is
/// persisted to the real case on the backend as it is given.
class GuidedReportScreen extends StatefulWidget {
  const GuidedReportScreen({super.key, required this.id});
  final String id;
  @override
  State<GuidedReportScreen> createState() => _GuidedReportScreenState();
}

const _assistantBubble = Color(0xFFE6F6F8);

class _GuidedReportScreenState extends State<GuidedReportScreen> {
  Future<MissingCase>? _data;
  MissingCase? _value;
  Map<String, dynamic> _answers = {};
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  Object? _error;

  /// Keeps the newest exchange in view, like a conversation should.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

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
    _scroll.dispose();
    super.dispose();
  }

  int get _step {
    if (_answers['same_location'] == null) return 0;
    if (_answers['same_location'] == false &&
        (_answers['last_seen_description'] ?? '').isEmpty) {
      return 1;
    }
    if ((_answers['clothing'] ?? '').isEmpty) return 2;
    if (_answers['carrying_distinctive'] == null) return 3;
    if (_answers['carrying_distinctive'] == true &&
        (_answers['distinctive_description'] ?? '').isEmpty) {
      return 4;
    }
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
          // Real current location, only with the Guardian's permission --
          // never invented, and never captured at all when they answer No.
          if (!await Geolocator.isLocationServiceEnabled()) {
            throw const AppFailure('locationRequired');
          }
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            throw const AppFailure('locationRequired');
          }
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
      if (mounted) {
        setState(() {
          _value = value;
          _answers = Map.of(value.report ?? {});
          _text.clear();
        });
        _scrollToEnd();
      }
      if (mounted && next['completed'] == true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.reportSaved)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            showAppBar: false,
            controller: _scroll,
            bottomNavigationBar: value == null ? null : _inputBar(s, step),
            children: [
              _header(s, value),
              const SizedBox(height: 16),
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
                GuardianPanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      IndividualPhoto(id: value.individualId, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: value.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  fontSize: 15,
                                ),
                                children: [
                                  TextSpan(
                                    text: '  ${s.ageYears('${value.age}')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: mutedText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.reportedByGuardian,
                              style: const TextStyle(
                                color: mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(status: value.status),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.todayJustNow,
                      style: const TextStyle(fontSize: 12, color: mutedText),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _assistant(s.assistantIntro(value.name)),
                _assistant(questions[0], hint: s.locationHint),
                if (_answers['same_location'] != null)
                  _reply(
                    _answers['same_location'] == true ? s.yes : s.no,
                    note: _answers['same_location'] == true
                        ? s.locationReady
                        : null,
                  ),
                if (_answers['same_location'] == false) ...[
                  _assistant(questions[1]),
                  if ((_answers['last_seen_description'] ?? '').isNotEmpty)
                    _reply(_answers['last_seen_description'] as String),
                ],
                if (step >= 2) ...[
                  _assistant(questions[2]),
                  if ((_answers['clothing'] ?? '').isNotEmpty)
                    _reply(_answers['clothing'] as String),
                ],
                if (step >= 3) ...[
                  _assistant(questions[3]),
                  if (_answers['carrying_distinctive'] != null)
                    _reply(
                      _answers['carrying_distinctive'] == true ? s.yes : s.no,
                    ),
                ],
                if (step >= 4 && _answers['carrying_distinctive'] == true) ...[
                  _assistant(questions[4]),
                  if ((_answers['distinctive_description'] ?? '').isNotEmpty)
                    _reply(_answers['distinctive_description'] as String),
                ],
                if (step >= 5) ...[
                  _assistant(questions[5]),
                  if ((_answers['additional_information'] ?? '').isNotEmpty)
                    _reply(_answers['additional_information'] as String),
                ],
                if (step == 6) _assistant(s.reportSaved),
                if (_answers['same_location'] != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              s.answersAutoSave,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

  Widget _header(AppLocalizations s, MissingCase? value) => Row(
    children: [
      const BackButton(color: AppColors.primary),
      Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.reportingAssistant,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
            if (value != null && value.active)
              Row(
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF2E9E6E),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      s.activeCase.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                        color: Color(0xFF2E9E6E),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      if (value != null) ...[
        const SizedBox(width: 8),
        CaseIdChip(id: value.id),
      ],
    ],
  );

  Widget _assistant(String text, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bolt, size: 16, color: AppColors.secondary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: _assistantBubble,
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: Radius.circular(18),
                    topEnd: Radius.circular(18),
                    bottomEnd: Radius.circular(18),
                    bottomStart: Radius.circular(4),
                  ),
                ),
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    hint,
                    style: const TextStyle(fontSize: 12, color: mutedText),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 24),
      ],
    ),
  );

  Widget _reply(String text, {String? note}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(18),
              topEnd: Radius.circular(18),
              bottomStart: Radius.circular(18),
              bottomEnd: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 16, color: Colors.white),
            ],
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              note,
              style: const TextStyle(fontSize: 12, color: mutedText),
            ),
          ),
      ],
    ),
  );

  /// Bottom answer area: Yes/No for the two boolean questions, a rounded
  /// text field with a send button for the free-text ones, and "View
  /// Status" once every required answer has been saved.
  Widget _inputBar(AppLocalizations s, int step) {
    final Widget child;
    if (step == 0 || step == 3) {
      child = Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _answer(choice: false),
              child: Text(s.no),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : () => _answer(choice: true),
              child: Text(s.yes),
            ),
          ),
        ],
      );
    } else if (step < 6) {
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(step == 5 ? 2000 : 1000),
              ],
              decoration: InputDecoration(
                hintText: s.typeAnswer,
                filled: true,
                fillColor: const Color(0xFFF4F7FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: const BorderSide(color: AppColors.secondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox.square(
            dimension: 52,
            child: FilledButton(
              onPressed: _busy ? null : () => _answer(),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(52, 52),
                shape: const CircleBorder(),
              ),
              child: Semantics(
                label: step == 5 ? s.saveReport : s.send,
                child: Icon(step == 5 ? Icons.check : Icons.send, size: 22),
              ),
            ),
          ),
        ],
      );
    } else {
      child = FilledButton(
        // The one-time workflow is over: the assistant is replaced by the
        // case's status screen rather than lingering on the stack.
        onPressed: () => Navigator.of(context)
            .pushReplacementNamed(AppRoutes.caseStatus, arguments: widget.id),
        child: Text(s.viewStatus),
      );
    }
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: AppColors.primary.withValues(alpha: .12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}
