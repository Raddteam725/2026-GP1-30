import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/app_text_input.dart';
import '../../auth/presentation/form_validation.dart';
import '../data/guardian_repository.dart';
import 'individual_widgets.dart';
import 'guardian_components.dart';
import 'retention_period_panel.dart';
import '../../../core/theme/app_colors.dart';

class IndividualFormScreen extends StatefulWidget {
  const IndividualFormScreen({super.key, this.individual});
  final Individual? individual;
  @override
  State<IndividualFormScreen> createState() => _IndividualFormScreenState();
}

class _IndividualFormScreenState extends State<IndividualFormScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final _name = TextEditingController(text: widget.individual?.fullName);
  late final _age = TextEditingController(
    text: widget.individual?.age.toString(),
  );
  late String? _gender = widget.individual?.gender,
      _relationship = widget.individual?.relationship;
  late final _relationshipOther = TextEditingController(
    text: widget.individual?.relationshipOther,
  );
  Uint8List? _photo;
  bool _busy = false, _photoError = false;
  Object? _error;
  // Retention choices: for a new registration, the event's currently valid
  // options (deadline previewed from now); for an existing one, the backend's
  // options counted from the original registration, with the current choice.
  List<RetentionChoice>? _choices;
  String? _periodId, _currentPeriodId;
  bool _requestedPeriods = false, _periodError = false;
  // Edit mode: the backend says whether retention may change (no active case).
  bool _retentionEditable = true;
  // The Active event this registration is automatically associated with --
  // read from the backend's authoritative event record, never assumed.
  ActiveEvent? _event;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedPeriods) {
      _requestedPeriods = true;
      _loadPeriods();
    }
  }

  Future<void> _loadPeriods() async {
    final guardian = AppServices.of(context).guardian;
    final existing = widget.individual;
    try {
      if (existing == null) {
        final periods = await guardian.registrationPeriods();
        final now = DateTime.now();
        if (!mounted) return;
        setState(() {
          _choices = [
            for (final p in periods)
              RetentionChoice(p.id, p.hours, now.add(Duration(hours: p.hours))),
          ];
          _periodError = periods.isEmpty;
        });
      } else {
        final options = await guardian.retentionOptions(existing.id);
        if (!mounted) return;
        setState(() {
          _choices = [
            for (final o in options.options)
              RetentionChoice(
                o.id,
                o.hours,
                o.expiresAt,
                available: o.available,
                reason: o.reason,
              ),
          ];
          _currentPeriodId = _periodId = options.currentPeriodId;
          _retentionEditable = options.editable;
          _periodError = options.options.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _periodError = true);
    }
    if (existing != null) return;
    try {
      final event = await guardian.activeEvent();
      if (mounted) setState(() => _event = event);
    } catch (_) {
      // No Active event: the periods panel already explains registration is
      // unavailable and saving stays disabled; nothing is invented here.
      if (mounted) setState(() => _event = null);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _age.dispose();
    _relationshipOther.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final photo = await Navigator.of(context).pushNamed(AppRoutes.camera);
    if (mounted && photo is Uint8List) {
      setState(() {
        _photo = photo;
        _photoError = false;
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (widget.individual == null && (_choices == null || _periodError)) return;
    final valid = _form.currentState!.validate();
    setState(() => _photoError = _photo == null && widget.individual == null);
    if (_photoError) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    if (!valid) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.of(context).guardian.saveIndividual(
        IndividualInput(
          // Edit: only a CHANGED retention choice is sent -- any other edit
          // (including a new photograph) leaves the deadline untouched.
          registrationPeriodId: widget.individual == null
              ? _periodId
              : (_periodId != _currentPeriodId ? _periodId : null),
          fullName: _name.text,
          age: int.parse(_age.text.trim()),
          gender: _gender!,
          relationship: _relationship!,
          relationshipOther: _relationship == 'other'
              ? _relationshipOther.text
              : null,
        ),
        id: widget.individual?.id,
        photo: _photo,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final editing = widget.individual != null;
    return PopScope(
      canPop: !_busy,
      child: FeaturePage(
        controller: _scroll,
        title: editing ? s.editIndividual : s.addIndividual,
        subtitle: editing ? null : s.addIndividualHint,
        bottomNavigationBar: GuardianNavigation(selected: 1, enabled: !_busy),
        children: [
          GuardianPanel(
            child: Column(
              children: [
                if (!editing) ...[
                  Row(
                    children: [
                      Expanded(
                        child: RequiredLabel(s.photoHeading, required: false),
                      ),
                      Text(
                        s.cameraRequired,
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        ' *',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                PhotoAvatar(
                  onTap: _busy ? null : _capture,
                  child: _photo != null
                      ? Image.memory(_photo!, fit: BoxFit.cover)
                      : editing
                      ? IndividualPhoto(id: widget.individual!.id, size: 128)
                      : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    backgroundColor: AppColors.lightBlue.withValues(alpha: .05),
                    side: const BorderSide(color: AppColors.secondary),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _busy ? null : _capture,
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: Text(
                    editing
                        ? s.changePhotoCamera
                        : _photo != null
                        ? s.retakePhoto
                        : s.takePhoto,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.cameraOnly,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
                ),
                if (_photoError) ErrorNotice(message: s.photoRequired),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GuardianPanel(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (editing) ...[
                    Text(
                      s.personalInformation,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  RequiredLabel(s.fullName),
                  const SizedBox(height: 8),
                  AppTextInput(
                    label: s.fullName,
                    showLabel: false,
                    hint: s.enterFullName,
                    controller: _name,
                    enabled: !_busy,
                    validator: (v) => FormValidation.name(v, s),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  RequiredLabel(s.age),
                  const SizedBox(height: 8),
                  AppTextInput(
                    label: s.age,
                    showLabel: false,
                    hint: s.enterAge,
                    controller: _age,
                    enabled: !_busy,
                    validator: (v) => FormValidation.age(v, s),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  RequiredLabel(s.gender),
                  const SizedBox(height: 8),
                  FormField<String>(
                    initialValue: _gender,
                    validator: (v) => FormValidation.required(v, s),
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (final value in ['female', 'male']) ...[
                              if (value == 'male') const SizedBox(width: 12),
                              Expanded(
                                child: Semantics(
                                  selected: _gender == value,
                                  inMutuallyExclusiveGroup: true,
                                  button: true,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _busy
                                        ? null
                                        : () {
                                            setState(() => _gender = value);
                                            field.didChange(value);
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _gender == value
                                            ? AppColors.secondary.withValues(
                                                alpha: .06,
                                              )
                                            : const Color(0xFFFAFCFD),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _gender == value
                                              ? AppColors.secondary
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _gender == value
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            size: 20,
                                            color: _gender == value
                                                ? AppColors.secondary
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              genderLabel(value, s),
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              field.errorText!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  RequiredLabel(s.relationship),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _relationship,
                    isExpanded: true,
                    hint: Text(s.selectRelationship),
                    decoration: const InputDecoration(),
                    items: [
                      for (final v in ['child', 'parent', 'other'])
                        DropdownMenuItem(
                          value: v,
                          child: Text(relationshipLabel(v, s)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _relationship = v),
                    validator: (v) => FormValidation.required(v, s),
                  ),
                  if (_relationship == 'other') ...[
                    const SizedBox(height: 20),
                    RequiredLabel(s.specifyRelationship),
                    const SizedBox(height: 8),
                    AppTextInput(
                      label: s.specifyRelationship,
                      showLabel: false,
                      hint: s.specifyRelationship,
                      controller: _relationshipOther,
                      enabled: !_busy,
                      validator: (v) => FormValidation.required(v?.trim(), s),
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Retention: chosen at registration, changeable from Edit while no
          // case locks the profile (the backend enforces both). A failed
          // options load is shown with a retry in BOTH modes -- never hidden.
          if (_periodError && (!editing || _retentionEditable))
            GuardianPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.registrationPeriodTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(s.registrationPeriodUnavailable),
                  TextButton(
                    onPressed: _busy ? null : _loadPeriods,
                    child: Text(s.retry),
                  ),
                ],
              ),
            )
          else if (_choices == null && !_periodError)
            const LinearProgressIndicator()
          else if (_choices != null && (!editing || _retentionEditable))
            RetentionPeriodPanel(
              choices: _choices!,
              selectedId: _periodId,
              editing: editing,
              enabled: !_busy,
              eventName: editing ? null : _event?.name,
              onChanged: (value) => setState(() => _periodId = value),
            ),
          if (_error != null) ErrorNotice(message: failureMessage(_error!, s)),
          PrimaryButton(
            label: editing ? s.saveChanges : s.save,
            onPressed: !editing && (_choices == null || _periodError)
                ? null
                : _save,
            isLoading: _busy,
          ),
        ],
      ),
    );
  }
}
