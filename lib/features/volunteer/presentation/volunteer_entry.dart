import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/auth_screen.dart';
import '../data/api_volunteer_repository.dart';
import 'volunteer_components.dart';
import 'volunteer_workspace.dart';

/// Protected Volunteer destination; login/reset/logout use the shared auth stack.
class VolunteerEntry extends StatefulWidget {
  const VolunteerEntry({super.key});
  @override
  State<VolunteerEntry> createState() => _VolunteerEntryState();
}

class _VolunteerEntryState extends State<VolunteerEntry> {
  ApiVolunteerRepository? _repository;
  StreamSubscription<bool>? _authEvents;
  bool _started = false, _leaving = false;
  Object? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final services = AppServices.maybeOf(context);
    if (services == null || !services.auth.signedIn) return;
    _authEvents = services.auth.changes.listen((signedIn) {
      if (!signedIn && mounted && !_leaving) _leave();
    });
    _load();
  }

  Future<void> _load() async {
    String? sessionUid;
    final repo = ApiVolunteerRepository(
      token: () async {
        final user = FirebaseAuth.instance.currentUser;
        sessionUid ??= user?.uid;
        // A late callback from a previous workspace must never authenticate
        // using a different account that subsequently signed in.
        if (user == null || user.uid != sessionUid) return null;
        try {
          return await user.getIdToken();
        } on FirebaseAuthException catch (error) {
          if (const {
            'user-disabled',
            'user-token-expired',
            'invalid-user-token',
            'user-not-found',
          }.contains(error.code)) {
            return null; // Repository clears protected state and uses shared logout.
          }
          rethrow; // A network error is not proof that the session was revoked.
        }
      },
      onAccessLost: (reason) => _leave(reason: reason),
    );
    try {
      await repo.loadProfile();
      if (!mounted || _leaving) {
        repo.dispose();
        return;
      }
      setState(() {
        _repository = repo;
        _error = null;
      });
    } catch (error) {
      debugPrint('Radd Volunteer profile load failed (${error.runtimeType})');
      repo.dispose();
      if (mounted && !_leaving) setState(() => _error = error);
    }
  }

  Future<void> _leave({String? reason}) async {
    if (_leaving || !mounted) return;
    _leaving = true;
    final auth = AppServices.of(context).auth;
    setState(() {
      _repository?.clearProtectedData();
    });
    await _repository?.closeSession?.call();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.auth, (_) => false, arguments: reason);
  }

  @override
  void dispose() {
    _authEvents?.cancel();
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_leaving) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final services = AppServices.maybeOf(context);
    if (services == null || !services.auth.signedIn) {
      return const AuthScreen(volunteer: true);
    }
    final repo = _repository;
    if (repo?.account != null) {
      return VolunteerWorkspace(
        account: repo!.account!,
        repository: repo,
        onLogout: _leave,
      );
    }
    return Scaffold(
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(stringsOf(context).vLoadFailed),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _load();
                    },
                    child: Text(stringsOf(context).vTryAgain),
                  ),
                  TextButton(
                    onPressed: _leave,
                    child: Text(stringsOf(context).logout),
                  ),
                ],
              ),
      ),
    );
  }
}
