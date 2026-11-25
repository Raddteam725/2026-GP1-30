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
  late int? _age = widget.individual?.age;
  late String? _gender = widget.individual?.gender,
      _relationship = widget.individual?.relationship;
  late final _relationshipOther = TextEditingController(
    text: widget.individual?.relationshipOther,
  );
  Uint8List? _photo;
  bool _busy = false, _photoError = false;
  Object? _error;
  List<RetentionChoice>? _choices;
  String? _periodId, _currentPeriodId;
  bool _requestedPeriods = false, _periodError = false;
  bool _retentionEditable = true;
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
      if (mounted) setState(() => _event = null);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
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
    final invalidFields = _form.currentState!.validateGranularly();
    setState(() => _photoError = _photo == null && widget.individual == null);
    if (_photoError) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    if (invalidFields.isNotEmpty) {
      await Scrollable.ensureVisible(
        invalidFields.first.context,
        alignment: .15,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.of(context).guardian.saveIndividual(
        IndividualInput(
          registrationPeriodId: widget.individual == null
              ? _periodId
              : (_periodId != _currentPeriodId ? _periodId : null),
          fullName: _name.text,
          age: _age!,
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
                      ? Image.memory(
                          _photo!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        )
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
                  _BlurValidatedInput(child: AppTextInput(
                    label: s.fullName,
                    showLabel: false,
                    hint: s.enterFullName,
                    controller: _name,
                    enabled: !_busy,
                    validator: (v) => FormValidation.name(v, s),
                    textInputAction: TextInputAction.next,
                  )),
                  const SizedBox(height: 20),
                  RequiredLabel(s.age),
                  const SizedBox(height: 8),
                  FormField<int>(
                    key: const ValueKey('individual-age'),
                    initialValue: _age,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => FormValidation.age(v?.toString(), s),
                    builder: (field) => _IndividualDropdown<int>(
                      menuId: 'individual-age-menu',
                      value: field.value,
                      values: List.generate(131, (age) => age),
                      label: (age) => '$age',
                      hint: s.enterAge,
                      enabled: !_busy,
                      errorText: field.errorText,
                      onChanged: (value) {
                        setState(() => _age = value);
                        field.didChange(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  RequiredLabel(s.gender),
                  const SizedBox(height: 8),
                  FormField<String>(
                    key: const ValueKey('individual-gender'),
                    initialValue: _gender,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  FormField<String>(
                    key: const ValueKey('individual-relationship'),
                    initialValue: _relationship,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => FormValidation.required(v, s),
                    builder: (field) => _IndividualDropdown<String>(
                      menuId: 'individual-relationship-menu',
                      value: field.value,
                      values: const ['child', 'parent', 'other'],
                      label: (value) => relationshipLabel(value, s),
                      hint: s.selectRelationship,
                      enabled: !_busy,
                      errorText: field.errorText,
                      onChanged: (value) {
                        setState(() => _relationship = value);
                        field.didChange(value);
                      },
                    ),
                  ),
                  if (_relationship == 'other') ...[
                    const SizedBox(height: 20),
                    RequiredLabel(s.specifyRelationship),
                    const SizedBox(height: 8),
                    _BlurValidatedInput(child: AppTextInput(
                      label: s.specifyRelationship,
                      showLabel: false,
                      hint: s.specifyRelationship,
                      controller: _relationshipOther,
                      enabled: !_busy,
                      validator: (v) => FormValidation.required(v?.trim(), s),
                      textInputAction: TextInputAction.done,
                    )),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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

class _IndividualDropdown<T> extends StatefulWidget {
  const _IndividualDropdown({
    required this.menuId,
    required this.value,
    required this.values,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final String menuId;
  final T? value;
  final List<T> values;
  final String Function(T) label;
  final String hint;
  final bool enabled;
  final String? errorText;
  final ValueChanged<T?> onChanged;

  @override
  State<_IndividualDropdown<T>> createState() => _IndividualDropdownState<T>();
}

class _IndividualDropdownState<T> extends State<_IndividualDropdown<T>> {
  final _link = LayerLink();
  final _overlay = OverlayPortalController();
  final _menuScroll = ScrollController();
  double _width = 0;

  void _open() {
    if (!widget.enabled || _overlay.isShowing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(_overlay.show);
    _jumpToValue();
  }

  void _close({bool selected = false}) {
    if (!_overlay.isShowing) return;
    setState(_overlay.hide);
    if (!selected) widget.onChanged(widget.value);
  }

  void _jumpToValue() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_menuScroll.hasClients) return;
      final value = widget.value;
      if (value == null) return;
      final index = widget.values.indexOf(value);
      if (index < 0) return;
      _menuScroll.jumpTo(
        (index * 48.0).clamp(0.0, _menuScroll.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _menuScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_overlay.isShowing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _overlay.isShowing) _close();
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return OverlayPortal(
          controller: _overlay,
          overlayChildBuilder: (overlayContext) {
            final box = this.context.findRenderObject()! as RenderBox;
            final top = box.localToGlobal(Offset.zero).dy;
            final bottom = top + box.size.height;
            final media = MediaQuery.of(overlayContext);
            final desiredHeight = (widget.values.length * 48.0).clamp(0.0, 280.0);
            final below = (media.size.height - media.viewInsets.bottom -
                media.padding.bottom - bottom - 4).clamp(0.0, double.infinity);
            final above = (top - media.padding.top - 4).clamp(0.0, double.infinity);
            final opensAbove = below < desiredHeight && above > 0;
            final height = desiredHeight.clamp(0.0, opensAbove ? above : below);
            return Positioned(
              left: 0,
              top: 0,
              width: _width,
              child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: opensAbove ? Alignment.topLeft : Alignment.bottomLeft,
                followerAnchor: opensAbove ? Alignment.bottomLeft : Alignment.topLeft,
                offset: Offset(0, opensAbove ? -4 : 4),
                child: TapRegion(
                  groupId: this,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      key: ValueKey(widget.menuId),
                      height: height,
                      child: ListView.builder(
                        controller: _menuScroll,
                        padding: EdgeInsets.zero,
                        itemExtent: 48,
                        itemCount: widget.values.length,
                        itemBuilder: (context, index) {
                          final value = widget.values[index];
                          return InkWell(
                            onTap: () {
                              widget.onChanged(value);
                              _close(selected: true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(widget.label(value)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: CompositedTransformTarget(
            link: _link,
            child: TapRegion(
              groupId: this,
              onTapOutside: (_) => _close(),
              child: InkWell(
                canRequestFocus: false,
                onTap: widget.enabled ? _open : null,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  isFocused: _overlay.isShowing,
                  isEmpty: !widget.values.contains(widget.value),
                  decoration: InputDecoration(
                    enabled: widget.enabled,
                    hintText: widget.hint,
                    errorText: _overlay.isShowing ? null : widget.errorText,
                    errorMaxLines: 3,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(widget.values.contains(widget.value)
                      ? widget.label(widget.value as T) : ''),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _BlurValidatedInput extends StatefulWidget {
  const _BlurValidatedInput({required this.child});
  final Widget child;

  @override
  State<_BlurValidatedInput> createState() => _BlurValidatedInputState();
}

class _BlurValidatedInputState extends State<_BlurValidatedInput> {
  final _focus = FocusNode();
  final _key = GlobalKey();
  bool _touched = false;

  void _focusChanged(bool hasFocus) {
    if (hasFocus) {
      _touched = true;
    } else if (_touched && mounted) {
      void validate(Element element) {
        if (element is StatefulElement && element.state is FormFieldState<String>) {
          (element.state as FormFieldState<String>).validate();
        } else {
          element.visitChildren(validate);
        }
      }
      _key.currentContext?.visitChildElements(validate);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    groupId: this,
    onTapOutside: (_) {
      if (_focus.hasFocus) _focus.unfocus();
    },
    child: Focus(
      key: _key,
      focusNode: _focus,
      canRequestFocus: false,
      onFocusChange: _focusChanged,
      child: widget.child,
    ),
  );
}
