import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../shared/widgets/app_text_input.dart';
import '../../../shared/widgets/password_input.dart';
import '../../../shared/widgets/required_checkbox.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../onboarding/presentation/widgets/onboarding_layout.dart';
import '../../guardian/data/guardian_repository.dart';
import '../data/registration_draft.dart';
import '../data/auth_service.dart';
import 'email_verification_screen.dart';
import 'form_validation.dart';

enum AuthMode { login, register, reset, completeProfile }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.mode = AuthMode.login,
    this.volunteer = false,
    this.notice,
  });
  final bool volunteer;
  final String? notice;
  final AuthMode mode;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  DialogRoute<void>? _verificationDialog;
  DialogRoute<String>? _credentialDialog;
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false, _adult = false, _privacy = false, _sent = false;
  Object? _error;
  bool _accountCreated = false, _draftLoaded = false, _inlinePending = false;
  String? _registrationUid;
  AuthIdentity? _registrationIdentity;
  String? _pendingEmail;
  DateTime? _resendAt;
  bool _editingAccount = false, _changePassword = false;
  bool _restoringDraft = false, _finalizing = false;
  int _draftVersion = 0;
  bool get _fieldsLocked => _busy || _inlinePending || _restoringDraft;
  bool get _register =>
      widget.mode == AuthMode.register ||
      widget.mode == AuthMode.completeProfile;

  void _closeVerificationDialog() {
    final route = _verificationDialog;
    _verificationDialog = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  void _showVerificationDialog({
    bool verificationSent = false,
    Object? sendError,
  }) {
    if (!mounted || _verificationDialog != null) return;
    setState(() => _inlinePending = true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmailVerificationScreen(
        registrationIdentity: _registrationIdentity,
        email: _email.text.trim(),
        verificationSent: verificationSent,
        initialError: sendError,
        inDialog: true,
        onVerified: _finishRegistration,
        onEdit: widget.mode == AuthMode.register && _accountCreated
            ? _editInformation
            : null,
        discardCurrentAttempt: widget.mode == AuthMode.register && _accountCreated
            ? _discardCurrentAttempt
            : null,
      ),
    );
    _verificationDialog = route;
    unawaited(
      Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
        if (identical(_verificationDialog, route)) {
          _verificationDialog = null;
          if (mounted) setState(() => _inlinePending = false);
        }
      }),
    );
  }

  void _editInformation(String? pendingEmail) {
    _closeVerificationDialog();
    setState(() {
      _inlinePending = false;
      _accountCreated = false;
      _editingAccount = false;
      _changePassword = false;
      _pendingEmail = null;
      _registrationUid = null;
      _registrationIdentity = null;
      _error = null;
    });
  }

  Future<bool> _discardCurrentAttempt() async {
    if (widget.mode != AuthMode.register || !_accountCreated) {
      throw const AppFailure('unauthorized');
    }
    _requireRegistrationUid();
    final deleted = await AppServices.of(context).auth
        .deleteUnverifiedRegistration(_registrationUid!);
    if (deleted) _accountCreated = false;
    return deleted;
  }

  void _requireRegistrationUid() {
    if (!mounted ||
        AppServices.of(context).auth.currentIdentity?.uid != _registrationUid ||
        _registrationUid == null) {
      throw const AppFailure('unauthorized');
    }
  }

  Future<String?> _requestCurrentPassword() async {
    final s = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final route = DialogRoute<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('registration-reauthentication'),
        scrollable: true,
        title: Text(s.registrationConfirmIdentity),
        content: Form(
          key: form,
          child: PasswordInput(
            label: s.registrationCurrentPassword,
            controller: controller,
            validator: (value) => FormValidation.required(value, s),
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
    _credentialDialog = route;
    try {
      final result = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      await route.completed;
      return result;
    } finally {
      if (identical(_credentialDialog, route)) _credentialDialog = null;
      controller.clear();
      controller.dispose();
    }
  }

  Future<bool> _confirmEmailChange(String email) async {
    _requireRegistrationUid();
    final auth = AppServices.of(context).auth;
    final language = Localizations.localeOf(context).languageCode;
    final password = await _requestCurrentPassword();
    if (!mounted || password == null) return false;
    _requireRegistrationUid();
    try {
      await auth.verifyNewEmail(email, password, language);
    } on AppFailure catch (error) {
      if (error.code == 'rateLimit') await _rememberEmailRequest();
      rethrow;
    }
    _requireRegistrationUid();
    _pendingEmail = email;
    await _rememberEmailRequest(email: email);
    return true;
  }

  Future<void> _rememberEmailRequest({String? email}) async {
    _resendAt = DateTime.now().add(const Duration(seconds: 60));
    try {
      await RegistrationDraft.update(_registrationUid!, {
        'pendingEmail': ?email,
        'resendAt': _resendAt!.toIso8601String(),
      });
    } catch (_) {}
  }

  Future<bool> _saveAccountChanges(AuthIdentity identity) async {
    _requireRegistrationUid();
    final auth = AppServices.of(context).auth;
    Map<String, dynamic> data = {};
    try {
      data = await RegistrationDraft.read(identity.uid);
    } catch (_) {}
    _requireRegistrationUid();
    _pendingEmail = data['pendingEmail'] as String? ?? _pendingEmail;
    _resendAt =
        DateTime.tryParse(data['resendAt'] as String? ?? '') ?? _resendAt;
    final target = _email.text.trim();
    if (_editingAccount &&
        target.toLowerCase() != identity.email.toLowerCase() &&
        target.toLowerCase() != _pendingEmail?.toLowerCase()) {
      if (_resendAt != null && _resendAt!.isAfter(DateTime.now())) {
        throw const AppFailure('registrationCooldown');
      }
      if (!await _confirmEmailChange(target)) return false;
    }
    if (_changePassword) {
      _requireRegistrationUid();
      try {
        await auth.updatePassword(_password.text);
      } on AppFailure catch (error) {
        if (error.code != 'reauthenticate') rethrow;
        final current = await _requestCurrentPassword();
        if (!mounted || current == null) return false;
        _requireRegistrationUid();
        await auth.updatePassword(_password.text, currentPassword: current);
      }
      _requireRegistrationUid();
      _password.clear();
      _confirm.clear();
      _changePassword = false;
    }
    return true;
  }

  Future<void> _saveRegistrationDraft() async {
    if (_registrationUid == null) return;
    try {
      _requireRegistrationUid();
      await RegistrationDraft.update(_registrationUid!, {
        'registrationPending': true,
        'name': _name.text,
        'phone': _phone.text,
        'adult': _adult,
        'privacy': _privacy,
      });
    } catch (_) {
      // Keep the in-memory form usable if device storage is unavailable.
    }
  }

  Future<void> _returnToLogin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AppServices.of(context).auth.logout();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftLoaded || widget.mode != AuthMode.completeProfile) return;
    _draftLoaded = true;
    _restoringDraft = true;
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final initialIdentity = AppServices.maybeOf(context)?.auth.currentIdentity;
    _registrationIdentity = initialIdentity;
    final uid = initialIdentity?.uid;
    _registrationUid = uid;
    if (_email.text.isEmpty) _email.text = initialIdentity?.email ?? '';
    try {
      if (uid == null) return;
      final draft = await RegistrationDraft.read(uid);
      if (!mounted) return;
      if (AppServices.of(context).auth.currentIdentity?.uid != uid) return;
      _registrationUid = uid;
      // Restore this UID's non-credential input without overwriting current edits.
      if (_name.text.isEmpty) _name.text = draft['name'] as String? ?? '';
      if (_phone.text.isEmpty) _phone.text = draft['phone'] as String? ?? '';
      _pendingEmail = draft['pendingEmail'] as String?;
      _adult = draft['adult'] == true;
      _privacy = draft['privacy'] == true;
      _draftVersion++;
      _email.text = _pendingEmail ?? initialIdentity!.email;
      if (draft['registrationPending'] == true &&
          _adult &&
          _privacy &&
          FormValidation.name(_name.text, AppLocalizations.of(context)!) ==
              null &&
          FormValidation.phone(_phone.text, AppLocalizations.of(context)!) ==
              null) {
        final identity = await AppServices.of(context).auth.refreshIdentity();
        if (mounted &&
            identity.uid == uid &&
            identity.emailVerified &&
            (_pendingEmail == null ||
                identity.email.toLowerCase() == _pendingEmail!.toLowerCase())) {
          await _finishRegistration(identity);
        }
      }
    } catch (error) {
      // Re-entering missing profile data is safe; no Auth account is recreated.
      if (mounted && error is AppFailure) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _restoringDraft = false);
    }
  }

  @override
  void dispose() {
    _accountCreated = false;
    final dialog = _verificationDialog;
    final credentialDialog = _credentialDialog;
    _credentialDialog = null;
    if (credentialDialog != null && credentialDialog.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (credentialDialog.isActive) {
          credentialDialog.navigator?.removeRoute(credentialDialog);
        }
      });
    }
    _verificationDialog = null;
    if (dialog != null && dialog.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dialog.isActive && dialog.navigator?.mounted == true) {
          dialog.navigator!.removeRoute(dialog);
        }
      });
    }
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _finishRegistration(AuthIdentity identity) async {
    if (_finalizing) return;
    final services = AppServices.of(context);
    if (identity.uid != _registrationUid ||
        services.auth.currentIdentity?.uid != _registrationUid ||
        !identity.emailVerified ||
        identity.email.toLowerCase() != _email.text.trim().toLowerCase() ||
        (_pendingEmail != null &&
            identity.email.toLowerCase() != _pendingEmail!.toLowerCase())) {
      throw const AppFailure('unauthorized');
    }
    setState(() {
      _finalizing = true;
      _busy = true;
      _error = null;
      _email.text = identity.email;
    });
    try {
      // The API independently verifies the refreshed ID token and live Auth user
      // before writing the existing profile/consent schema. No local flag grants access.
      await services.guardian.createProfile(_name.text, _phone.text);
      try {
        await RegistrationDraft.clear(identity.uid);
      } catch (_) {}
      if (!mounted) return;
      _accountCreated = false;
      _closeVerificationDialog();
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.session,
        (_) => false,
        arguments: 'guardian',
      );
    } catch (error) {
      if (!mounted) return;
      _closeVerificationDialog();
      setState(() {
        _inlinePending = false;
        _error = error;
      });
    } finally {
      _finalizing = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_fieldsLocked) return;
    final valid = _form.currentState!.validate();
    if (!valid || (_register && (!_adult || !_privacy))) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final services = AppServices.of(context);
    try {
      if (widget.mode == AuthMode.reset) {
        await services.auth.resetPassword(_email.text);
        if (mounted) setState(() => _sent = true);
        return;
      } else if (_register) {
        if (widget.mode == AuthMode.register && !_accountCreated) {
          // Never adopt or modify an unrelated existing signed-in account.
          if (services.auth.signedIn) {
            if (mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.session, (_) => false);
            }
            return;
          }
          await services.auth.register(_email.text, _password.text);
          if (!mounted) return;
          _accountCreated = true;
          _registrationIdentity = services.auth.currentIdentity;
          _registrationUid = _registrationIdentity?.uid;
          if (_registrationUid == null) throw const AppFailure('unauthorized');
          await _saveRegistrationDraft();
          if (!mounted) return;
          Object? sendError;
          try {
            _requireRegistrationUid();
            await services.auth.sendVerification(
              Localizations.localeOf(context).languageCode,
            );
          } catch (error) {
            sendError = error;
          }
          if (!mounted) return;
          _showVerificationDialog(
            verificationSent: sendError == null,
            sendError: sendError,
          );
          return;
        }
        var identity = await services.auth.refreshIdentity();
        if (!mounted) return;
        if (widget.mode == AuthMode.completeProfile) {
          _registrationUid ??= identity.uid;
        }
        if (identity.uid != _registrationUid) {
          throw const AppFailure('unauthorized');
        }
        _registrationIdentity = identity;
        await _saveRegistrationDraft();
        if (_accountCreated && !await _saveAccountChanges(identity)) return;
        if (!mounted) return;
        identity = await services.auth.refreshIdentity();
        _requireRegistrationUid();
        if (_pendingEmail != null &&
            _email.text.trim().toLowerCase() != _pendingEmail!.toLowerCase()) {
          throw const AppFailure('registrationPendingEmail');
        }
        if (!identity.emailVerified ||
            identity.email.toLowerCase() != _email.text.trim().toLowerCase()) {
          _editingAccount = false;
          _showVerificationDialog();
          return;
        }
        await _finishRegistration(identity);
        return;
      } else {
        await services.auth.login(_email.text, _password.text);
      }
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.session,
          (_) => false,
          arguments: widget.volunteer ? null : 'guardian-login',
        );
      }
    } catch (error) {
      if (mounted &&
          _register &&
          _registrationUid != null &&
          error is AppFailure &&
          error.code == 'unauthorized') {
        _showVerificationDialog();
        return;
      }
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final reset = widget.mode == AuthMode.reset,
        complete = widget.mode == AuthMode.completeProfile,
        signUp = widget.mode == AuthMode.register;
    final heading = complete
        ? s.completeProfile
        : reset
        ? s.resetTitle
        : _register
        ? s.createTitle
        : widget.volunteer
        ? s.volunteerLogin
        : s.welcomeBack;
    return PopScope(
      canPop: widget.mode != AuthMode.register || (!_busy && !_inlinePending),
      child: FeaturePage(
        headerInBody: true,
        showAppBar: !complete,
        title: heading,
        children: [
          if ((widget.notice == 'volunteer_inactive' ||
              widget.notice == 'account_disabled'))
            ErrorNotice(message: s.vAccountDeactivated),
          if (!_register)
            Center(
              child: Image.asset(
                OnboardingLayout.logoAsset,
                width: 80,
                height: 80,
              ),
            ),
          const SizedBox(height: 24),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? s.completeProfileHint
                : reset
                ? s.resetHint
                : _register
                ? s.createHint
                : s.loginHint,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Password reset: after the real Firebase request has been made,
          // the same confirmation is shown whether or not an account exists
          // for the address (no account enumeration).
          if (reset && _sent)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: .1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 36,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.resetSentTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          s.resetSent,
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: s.backToLogin,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  onPressed: () => setState(() => _sent = false),
                  child: Text(s.resendReset),
                ),
              ],
            )
          else
            Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_register) ...[
                      AppTextInput(
                        label: s.fullName,
                        prefixIcon: const Icon(Icons.person_outline),
                        controller: _name,
                        enabled: !_fieldsLocked,
                        validator: (v) => FormValidation.name(v, s),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!complete) ...[
                      AppTextInput(
                        label: s.email,
                        hint: s.emailPlaceholder,
                        prefixIcon: const Icon(Icons.email_outlined),
                        controller: _email,
                        enabled:
                            !_fieldsLocked &&
                            (!_accountCreated || _editingAccount),
                        validator: (v) => FormValidation.email(v, s),
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_register) ...[
                      AppTextInput(
                        label: s.phone,
                        helperText: s.phoneHelp,
                        helperStyle: Theme.of(context).textTheme.bodySmall,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        controller: _phone,
                        enabled: !_fieldsLocked,
                        validator: (v) => FormValidation.phone(v, s),
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (signUp && _accountCreated && _editingAccount)
                      TextButton(
                        onPressed: _fieldsLocked
                            ? null
                            : () => setState(() {
                                _changePassword = !_changePassword;
                                _password.clear();
                                _confirm.clear();
                              }),
                        child: Text(
                          _changePassword
                              ? s.cancel
                              : s.registrationChangePassword,
                        ),
                      ),
                    if (!reset &&
                        !complete &&
                        (!_accountCreated || _changePassword)) ...[
                      PasswordInput(
                        label: s.password,
                        helperText: _register ? s.passwordHelp : null,
                        helperStyle: Theme.of(context).textTheme.bodySmall,
                        errorMaxLines: _register ? 8 : 3,
                        controller: _password,
                        // Rebuild to revalidate an already edited confirmation
                        // when its source password changes, without touching
                        // any pristine fields.
                        onChanged: (_) => setState(() {}),
                        enabled: !_fieldsLocked,
                        validator: (v) => _register
                            ? FormValidation.password(v, s)
                            : FormValidation.required(v, s),
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: signUp
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: signUp ? null : (_) => _submit(),
                      ),
                      if (signUp) ...[
                        const SizedBox(height: 16),
                        PasswordInput(
                          label: s.confirmPassword,
                          controller: _confirm,
                          enabled: !_fieldsLocked,
                          validator: (v) => FormValidation.confirmPassword(
                            v,
                            _password.text,
                            s,
                          ),
                          autofillHints: const [AutofillHints.newPassword],
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (_register) ...[
                      RequiredCheckbox(
                        key: ValueKey('registration-adult-$_draftVersion'),
                        value: _adult,
                        enabled: !_fieldsLocked,
                        onChanged: (v) {
                          setState(() => _adult = v);
                          unawaited(_saveRegistrationDraft());
                        },
                        label: Text(s.ageConfirm),
                        errorText: s.requiredField,
                      ),
                      RequiredCheckbox(
                        key: ValueKey('registration-privacy-$_draftVersion'),
                        value: _privacy,
                        enabled: !_fieldsLocked,
                        onChanged: (v) {
                          setState(() => _privacy = v);
                          unawaited(_saveRegistrationDraft());
                        },
                        label: Text(s.privacyConfirm),
                        errorText: s.requiredField,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.privacy),
                          child: Text(s.privacyTitle),
                        ),
                      ),
                    ],
                    if (!_register && !reset)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () =>
                                    Navigator.of(context)
                                        .pushNamed(AppRoutes.forgotPassword),
                          child: Text(s.forgotPassword),
                        ),
                      ),
                    if (_error != null && !_inlinePending)
                      ErrorNotice(
                        message:
                            _error is AppFailure &&
                                (_error as AppFailure).code ==
                                    'registrationPendingEmail'
                            ? s.registrationPendingEmailHint
                            : _error is AppFailure &&
                                  (_error as AppFailure).code ==
                                      'registrationCooldown'
                            ? s.verificationCooldown(
                                (_resendAt!
                                            .difference(DateTime.now())
                                            .inMilliseconds /
                                        1000)
                                    .ceil()
                                    .clamp(0, 60),
                              )
                            : failureMessage(_error!, s),
                      ),
                    PrimaryButton(
                      label: reset
                          ? s.sendReset
                          : complete
                          ? s.save
                          : _register
                          ? s.createAccount
                          : s.login,
                      onPressed: _inlinePending
                          ? _showVerificationDialog
                          : _submit,
                      isLoading: _busy || _restoringDraft,
                    ),
                    const SizedBox(height: 16),
                    if (!_register && !reset && !widget.volunteer) ...[
                      Text(s.noAccount, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () =>
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.createAccount),
                        child: Text(s.createAccount),
                      ),
                    ],
                    if ((complete || _accountCreated) && !_inlinePending)
                      TextButton(
                        onPressed: _busy ? null : _returnToLogin,
                        child: Text(s.verificationSignOut),
                      ),
                    if (reset)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text('${s.rememberPassword} ${s.login}'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The final Privacy Notice, in the app's currently selected language (the
/// localization system supplies Arabic/RTL or English/LTR -- there is no
/// language selector here). Read-only; agreement is the separate required
/// checkbox on the registration form.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final sections = [
      (s.privacyInfoTitle, s.privacyInfoBody),
      (s.privacyRegisteredPhotosTitle, s.privacyRegisteredPhotosBody),
      (s.privacyVolunteerPhotosTitle, s.privacyVolunteerPhotosBody),
      (s.privacyLocationTitle, s.privacyLocationBody),
      (s.privacyUsageTitle, s.privacyUsageBody),
      (s.privacyAccessTitle, s.privacyAccessBody),
      (s.privacyRetentionTitle, s.privacyRetentionBody),
      (s.privacyStatisticsTitle, s.privacyStatisticsBody),
      (s.privacyAgreementTitle, s.privacyAgreementBody),
    ];
    const body = TextStyle(fontSize: 15, height: 1.7, color: AppColors.text);
    return FeaturePage(
      title: s.privacyTitle,
      children: [
        Text(s.privacyIntro, style: body),
        for (final (title, text) in sections) ...[
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(text, style: body),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
