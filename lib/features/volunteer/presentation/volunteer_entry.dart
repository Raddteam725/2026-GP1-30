import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_locale_scope.dart';
import '../../../shared/widgets/password_input.dart';
import '../data/volunteer_auth_service.dart';
import '../data/api_volunteer_repository.dart';
import '../data/volunteer_repository.dart';
import '../data/mock_volunteer_repository.dart';
import '../domain/volunteer_models.dart';
import 'volunteer_components.dart';
import 'volunteer_workspace.dart';

class VolunteerEntry extends StatefulWidget {
  const VolunteerEntry({super.key});
  @override
  State<VolunteerEntry> createState() => _VolunteerEntryState();
}

class _VolunteerEntryState extends State<VolunteerEntry> {
  final _auth = VolunteerAuthService();
  final _email = TextEditingController(), _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false, _reset = false;
  String? _errorCode;
  VolunteerAccount? _account;
  VolunteerRepository? _repository;
  StreamSubscription<User?>? _authSubscription;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _repository?.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _busy = true);
        try {
          await _enterAuthenticated();
        } catch (_) {
          if (mounted) setState(() => _errorCode = 'backend-unavailable');
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      });
    }
  }

  Future<void> _enterAuthenticated() async {
    final repository = ApiVolunteerRepository(
      token: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
    );
    try {
      await repository.loadProfile();
    } catch (_) {
      repository.dispose();
      await _auth.signOut();
      rethrow;
    }
    final account = repository.account!;
    if (!mounted) {
      repository.dispose();
      return;
    }
    _password.clear();
    _repository?.dispose();
    setState(() {
      _account = account;
      _repository = repository;
    });
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null &&
          mounted &&
          _account != null &&
          _repository?.isPreview != true) {
        _repository?.dispose();
        setState(() {
          _account = null;
          _repository = null;
        });
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      if (_reset) {
        await _auth.resetPassword(_email.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(stringsOf(context).vResetSent)),
          );
        }
      } else {
        await _auth.signIn(_email.text, _password.text);
        await _enterAuthenticated();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorCode = error is FirebaseAuthException
              ? error.code
              : error is StateError
              ? error.message
              : 'unavailable',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_repository?.isPreview != true) await _auth.signOut();
    await _authSubscription?.cancel();
    _authSubscription = null;
    if (mounted) {
      setState(() {
        _account = null;
        _password.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(context);
    if (_account != null) {
      return VolunteerWorkspace(
        account: _account!,
        repository: _repository!,
        onLogout: _logout,
      );
    }
    final error = switch (_errorCode) {
      null => null,
      'invalid-email' => s.vInvalidEmail,
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-login-credentials' => s.vInvalidLogin,
      'network-request-failed' => s.vNetworkError,
      'backend-unavailable' => s.vLoadFailed,
      'volunteer-required' || 'user-disabled' => s.vAccessDenied,
      _ => s.vUnavailable,
    };
    return Scaffold(
      backgroundColor: volunteerCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(s.volunteerRole),
        actions: [
          TextButton(
            onPressed: () => AppLocaleScope.of(context).setLocale(
              Locale(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'en'
                    : 'ar',
              ),
            ),
            child: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'English'
                  : 'العربية',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    'assets/images/radd_logo.png',
                    width: 88,
                    height: 88,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: VolunteerHeading(
                    _reset ? s.vReset : s.vWelcome,
                    large: true,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _reset ? s.vResetHint : s.vLoginHint,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: s.vEmail,
                          prefixIcon: const Icon(Icons.mail_outline),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? s.vRequired
                            : !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim())
                            ? s.vInvalidEmail
                            : null,
                      ),
                      const SizedBox(height: 22),
                      if (!_reset)
                        PasswordInput(
                          label: s.vPassword,
                          controller: _password,
                          enabled: !_busy,
                          validator: (value) => value == null || value.isEmpty
                              ? s.vRequired
                              : null,
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _reset = !_reset;
                                  _errorCode = null;
                                }),
                          child: Text(_reset ? s.vLogin : s.vForgot),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: const TextStyle(color: Color(0xFFB91C1C)),
                            ),
                          ),
                        ),
                      if (_busy)
                        const Center(child: CircularProgressIndicator())
                      else
                        VolunteerAction(
                          _reset ? s.vSendReset : s.vLogin,
                          onPressed: _submit,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  s.vAccountManaged,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF747783),
                  ),
                ),
                if (kDebugMode &&
                    (Firebase.apps.isEmpty ||
                        FirebaseAuth.instance.currentUser == null)) ...[
                  const SizedBox(height: 24),
                  VolunteerAction(
                    s.vPreviewOpen,
                    secondary: true,
                    onPressed: _busy
                        ? null
                        : () {
                            _repository?.dispose();
                            setState(() {
                              _repository = MockVolunteerRepository();
                              _account = MockVolunteerRepository.account;
                            });
                          },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
