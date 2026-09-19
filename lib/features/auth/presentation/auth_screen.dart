import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../shared/widgets/app_text_input.dart';
import '../../../shared/widgets/password_input.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../onboarding/presentation/widgets/onboarding_layout.dart';
import '../../guardian/data/guardian_repository.dart';
import 'form_validation.dart';

enum AuthMode { login, register, reset, completeProfile }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.mode = AuthMode.login,
    this.volunteer = false,
  });
  final bool volunteer;
  final AuthMode mode;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _password = TextEditingController();
  bool _busy = false,
      _adult = false,
      _privacy = false,
      _confirmError = false,
      _sent = false;
  Object? _error;
  bool _accountCreated = false;
  bool get _register =>
      widget.mode == AuthMode.register ||
      widget.mode == AuthMode.completeProfile;
  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final valid = _form.currentState!.validate();
    setState(() => _confirmError = _register && (!_adult || !_privacy));
    if (!valid || _confirmError) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final services = AppServices.maybeOf(context);
    try {
      if (services == null) throw const AppFailure('service');
      if (widget.mode == AuthMode.reset) {
        await services.auth.resetPassword(_email.text);
        if (mounted) setState(() => _sent = true);
        return;
      }
      if (_register) {
        if (widget.mode == AuthMode.register && !_accountCreated) {
          await services.auth.register(_email.text, _password.text);
          _accountCreated = true;
        }
        await services.guardian.createProfile(_name.text, _phone.text);
      } else {
        await services.auth.login(_email.text, _password.text);
      }
      // The protected destination verifies the persisted Guardian role, never a client-selected role.
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.session,
          (_) => false,
          arguments: widget.volunteer ? 'volunteer' : 'guardian',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              _accountCreated || widget.mode == AuthMode.completeProfile
              ? const AppFailure('profilePending')
              : e,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final reset = widget.mode == AuthMode.reset,
        complete = widget.mode == AuthMode.completeProfile;
    return PopScope(
      canPop: !_busy,
      child: FeaturePage(
        headerInBody: true,
        title: complete
            ? s.completeProfile
            : reset
            ? s.resetTitle
            : _register
            ? s.createTitle
            : widget.volunteer
            ? s.volunteerLogin
            : s.welcomeBack,
        children: [
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
            complete
                ? s.completeProfile
                : reset
                ? s.resetTitle
                : _register
                ? s.createTitle
                : widget.volunteer
                ? s.volunteerLogin
                : s.welcomeBack,
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
            complete || _accountCreated
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
                        enabled: !_busy,
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
                        enabled: !_busy && !_accountCreated,
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
                        prefixIcon: const Icon(Icons.phone_outlined),
                        controller: _phone,
                        enabled: !_busy,
                        validator: (v) => FormValidation.phone(v, s),
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.phoneHelp,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!reset && !complete) ...[
                      PasswordInput(
                        label: s.password,
                        controller: _password,
                        enabled: !_busy && !_accountCreated,
                        validator: (v) => _register
                            ? FormValidation.password(v, s)
                            : FormValidation.required(v, s),
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_register) ...[
                        const SizedBox(height: 8),
                        Text(
                          s.passwordHelp,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (_register) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _adult,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _adult = v!),
                        title: Text(s.ageConfirm),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _privacy,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _privacy = v!),
                        title: Text(s.privacyConfirm),
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
                      if (_confirmError)
                        ErrorNotice(message: s.confirmRequired),
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
                    if (_error != null)
                      ErrorNotice(message: failureMessage(_error!, s)),
                    PrimaryButton(
                      label: reset
                          ? s.sendReset
                          : complete || _accountCreated
                          ? s.save
                          : _register
                          ? s.createAccount
                          : s.login,
                      onPressed: _submit,
                      isLoading: _busy,
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
                    if (_register && !complete) ...[
                      Text(s.alreadyAccount, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(s.login),
                      ),
                    ],
                    if (complete || _accountCreated)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context)
                                  .pushNamedAndRemoveUntil(
                                    AppRoutes.roleSelection,
                                    (_) => false,
                                  ),
                        child: Text(s.returnToRoles),
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

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FeaturePage(
      title: s.privacyTitle,
      children: [Text(s.privacyBody, style: const TextStyle(height: 1.7))],
    );
  }
}
