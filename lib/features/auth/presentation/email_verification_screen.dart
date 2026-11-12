import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../guardian/data/guardian_repository.dart';
import '../data/auth_service.dart';
import '../data/registration_draft.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    this.sendOnOpen = false,
    this.inDialog = false,
    this.onVerified,
    this.onEdit,
    this.discardCurrentAttempt,
    this.registrationIdentity,
    this.email,
    this.verificationSent = false,
    this.initialError,
  });
  final bool sendOnOpen;
  final bool inDialog;
  final Future<void> Function(AuthIdentity)? onVerified;
  final ValueChanged<String?>? onEdit;
  final Future<bool> Function()? discardCurrentAttempt;
  final AuthIdentity? registrationIdentity;
  final String? email;
  final bool verificationSent;
  final Object? initialError;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  AuthIdentity? _identity;
  String? _pendingEmail;
  Object? _error;
  bool _busy = true, _checking = false, _started = false;
  bool _completionStarted = false, _resumePending = false;
  DateTime? _resendAt;
  int _remaining = 0;
  Timer? _countdownTimer, _verificationTimer;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted || _completionStarted) {
      return;
    }
    _watchCooldown();
    if (_busy || _checking) {
      _resumePending = true;
    } else {
      _check();
    }
  }

  void _startVerificationTimer() {
    _verificationTimer?.cancel();
    if (!mounted || _completionStarted) return;
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_busy && !_checking && !_completionStarted) _check();
    });
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _verificationTimer?.cancel();
  }

  void _idle() {
    if (!mounted) return;
    setState(() => _busy = false);
    if (_resumePending && !_checking && !_completionStarted) {
      _resumePending = false;
      _check();
    }
  }

  void _showFailure(Object error) {
    if (mounted) setState(() => _error = error);
  }

  Future<void> _load() async {
    final auth = AppServices.of(context).auth;
    _identity = widget.registrationIdentity ?? auth.currentIdentity;
    try {
      if (_identity == null) throw const AppFailure('unauthorized');
      Map<String, dynamic> data = {};
      try {
        data = await RegistrationDraft.read(_identity!.uid);
      } catch (_) {}
      if (!mounted) return;
      _pendingEmail = data['pendingEmail'] as String?;
      if (widget.verificationSent) {
        await _cooldown();
      } else if (widget.initialError == null) {
        _resendAt = DateTime.tryParse(data['resendAt'] as String? ?? '');
        _watchCooldown();
      }
      final identity = await auth.refreshIdentity();
      if (!mounted) return;
      if (identity.uid != _identity?.uid) {
        throw const AppFailure('unauthorized');
      }
      _identity = identity;
      if (_canContinue(identity)) {
        await _complete(identity);
      } else if (widget.sendOnOpen && _remaining == 0) {
        await _send(initial: true);
      }
    } catch (error) {
      if (widget.initialError == null) _showFailure(error);
    } finally {
      _idle();
      _startVerificationTimer();
    }
  }

  bool _canContinue(AuthIdentity identity) =>
      identity.emailVerified &&
      (_pendingEmail == null ||
          identity.email.toLowerCase() == _pendingEmail!.toLowerCase());

  Future<void> _complete(AuthIdentity identity) async {
    if (_completionStarted) return;
    setState(() => _completionStarted = true);
    _stopTimers();
    try {
      await _save({'pendingEmail': null});
      if (!mounted) return;
      if (widget.onVerified != null) {
        await widget.onVerified!(identity);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.session,
          (_) => false,
          arguments: 'guardian',
        );
      }
    } catch (_) {
      _completionStarted = false;
      _watchCooldown();
      _startVerificationTimer();
      rethrow;
    }
  }

  void _watchCooldown() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    final milliseconds =
        _resendAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    setState(() {
      _remaining = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    });
    if (_remaining == 0) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining = (_remaining - 1).clamp(0, 60));
      if (_remaining == 0) timer.cancel();
    });
  }

  Future<void> _cooldown() async {
    _resendAt = DateTime.now().add(const Duration(seconds: 60));
    _watchCooldown();
    await _save({'resendAt': _resendAt!.toIso8601String()});
  }

  Future<void> _save(Map<String, dynamic> values) async {
    try {
      await RegistrationDraft.update(_identity!.uid, values);
    } catch (_) {
      // Local hints never grant verification or access.
    }
  }

  Future<void> _send({bool initial = false}) async {
    if ((_busy && !initial) || _completionStarted || _remaining > 0) return;
    final auth = AppServices.of(context).auth;
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (auth.currentIdentity?.uid != _identity?.uid) {
        throw const AppFailure('unauthorized');
      }
      await auth.sendVerification(language);
      if (mounted) await _cooldown();
    } catch (error) {
      _showFailure(error);
    } finally {
      if (!initial) _idle();
    }
  }

  Future<void> _check() async {
    if (_busy || _checking || _completionStarted) return;
    setState(() => _checking = true);
    try {
      final identity = await AppServices.of(context).auth.refreshIdentity();
      if (!mounted) return;
      if (identity.uid != _identity?.uid) {
        throw const AppFailure('unauthorized');
      }
      _identity = identity;
      if (_canContinue(identity)) await _complete(identity);
    } catch (error) {
      if (error is! AppFailure || error.code != 'network') _showFailure(error);
    } finally {
      if (mounted) setState(() => _checking = false);
      if (_resumePending && mounted && !_completionStarted) {
        _resumePending = false;
        _check();
      }
    }
  }

  Future<void> _editInformation() async {
    if (_busy || _checking || _completionStarted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppServices.of(context).auth;
    final uid = _identity?.uid;
    try {
      if (uid == null) throw const AppFailure('unauthorized');
      if (widget.discardCurrentAttempt != null) {
        if (!await widget.discardCurrentAttempt!()) {
          final identity = await auth.refreshIdentity();
          if (identity.uid != uid || !_canContinue(identity)) {
            throw const AppFailure('unauthorized');
          }
          await _complete(identity);
          return;
        }
      } else {
        if (auth.currentIdentity?.uid != uid) {
          throw const AppFailure('unauthorized');
        }
        await auth.logout();
      }
      _stopTimers();
      try {
        await RegistrationDraft.clear(uid);
      } catch (_) {}
      if (!mounted) return;
      if (widget.onEdit != null) {
        widget.onEdit!(null);
      } else {
        final navigator = Navigator.of(context);
        navigator.pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false);
        navigator.pushNamed(AppRoutes.createAccount);
      }
    } catch (error) {
      _showFailure(error);
    } finally {
      _idle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final dialog = AlertDialog(
      key: const ValueKey('registration-verification-dialog'),
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(s.registrationVerifyEmailTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${s.registrationLinkSent} ${widget.email ?? _identity?.email ?? ''}',
          ),
          if (_error != null)
            Text(
              failureMessage(_error!, s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextButton(
            onPressed: _busy || _completionStarted || _remaining > 0
                ? null
                : _send,
            child: Text(
              _remaining > 0
                  ? '${s.registrationResendLink} (${s.verificationCooldown(_remaining)})'
                  : s.registrationResendLink,
            ),
          ),
          TextButton(
            onPressed: _busy || _checking || _completionStarted
                ? null
                : _editInformation,
            child: Text(s.registrationEditInformation),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: false,
      child: widget.inDialog ? dialog : Scaffold(body: Center(child: dialog)),
    );
  }
}
