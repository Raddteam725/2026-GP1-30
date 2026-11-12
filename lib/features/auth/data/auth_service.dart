import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../guardian/data/guardian_repository.dart';

/// A Firebase identity snapshot, never an application authorization decision.
class AuthIdentity {
  const AuthIdentity({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });
  final String uid;
  final String email;
  final bool emailVerified;
}

abstract class AuthService {
  bool get signedIn;
  AuthIdentity? get currentIdentity;
  Future<AuthIdentity> refreshIdentity();
  Future<void> sendVerification(String language);
  Future<void> verifyNewEmail(String email, String password, String language);
  Future<void> updatePassword(String password, {String? currentPassword});
  Future<bool> restoreSession();
  Stream<bool> get changes;
  Future<void> login(String email, String password);
  Future<void> register(String email, String password);
  Future<bool> deleteUnverifiedRegistration(String uid);
  Future<void> resetPassword(String email);
  Future<void> logout();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this.auth);
  final FirebaseAuth auth;
  @override
  bool get signedIn => auth.currentUser != null;
  AuthIdentity _identity(User user) => AuthIdentity(
    uid: user.uid,
    email: user.email ?? '',
    emailVerified: user.emailVerified,
  );
  @override
  AuthIdentity? get currentIdentity =>
      auth.currentUser == null ? null : _identity(auth.currentUser!);

  User get _user =>
      auth.currentUser ?? (throw const AppFailure('unauthorized'));

  @override
  Future<AuthIdentity> refreshIdentity() async {
    late AuthIdentity result;
    await _perform(() async {
      final uid = _user.uid;
      await _firebaseStep('reload', () => _user.reload());
      if (_user.uid != uid) throw const AppFailure('unauthorized');
      await _firebaseStep('refresh-token', () async {
        await _user.getIdToken(true);
      });
      if (_user.uid != uid) throw const AppFailure('unauthorized');
      result = _identity(_user);
    }, verification: true);
    return result;
  }

  @override
  Future<void> sendVerification(String language) => _perform(
    () async {
      await _firebaseStep(
        'send-email-verification',
        () => _user.sendEmailVerification(),
      );
    },
    verification: true,
    emailDispatch: true,
  );

  @override
  Future<void> verifyNewEmail(
    String email,
    String password,
    String language,
  ) => _perform(
    () async {
      final user = _user;
      final currentEmail = user.email;
      if (currentEmail == null) throw const AppFailure('unauthorized');
      // Reauthenticate against the ACTUAL current address, never the proposed
      // replacement. Firebase keeps the UID and verifies before changing it.
      await _firebaseStep('reauthenticate-email-correction', () async {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: currentEmail, password: password),
        );
      });
      if (_user.uid != user.uid) throw const AppFailure('unauthorized');
      await _firebaseStep(
        'verify-before-update-email',
        () => user.verifyBeforeUpdateEmail(email.trim()),
      );
    },
    verification: true,
    emailDispatch: true,
  );
  @override
  Future<void> updatePassword(String password, {String? currentPassword}) =>
      _perform(() async {
        final user = _user;
        if (currentPassword != null) {
          final email = user.email;
          if (email == null) throw const AppFailure('unauthorized');
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(
              email: email,
              password: currentPassword,
            ),
          );
          if (_user.uid != user.uid) throw const AppFailure('unauthorized');
        }
        await user.updatePassword(password);
        if (_user.uid != user.uid) throw const AppFailure('unauthorized');
      }, verification: true);

  @override
  Future<bool> restoreSession() async =>
      await auth.authStateChanges().first != null;
  @override
  Stream<bool> get changes => auth.authStateChanges().map((u) => u != null);

  // Report only operation names and SDK codes. Exception messages, identities,
  // credentials, tokens and email action links must never enter these logs.
  Future<void> _firebaseStep(
    String operation,
    Future<void> Function() action,
  ) async {
    if (kDebugMode) {
      debugPrint('RaddAuth operation=$operation status=requested');
    }
    try {
      await action();
      if (kDebugMode) {
        debugPrint('RaddAuth operation=$operation status=completed');
      }
    } on FirebaseAuthException catch (error) {
      final code = RegExp(r'^[a-z0-9-]+$').hasMatch(error.code)
          ? error.code
          : 'unrecognized-code';
      if (kDebugMode) {
        debugPrint('RaddAuth operation=$operation status=rejected code=$code');
      }
      rethrow;
    }
  }

  Future<void> _perform(
    Future<void> Function() action, {
    bool reset = false,
    bool verification = false,
    bool emailDispatch = false,
  }) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (reset &&
          {
            'user-not-found',
            'invalid-email',
            'invalid-credential',
          }.contains(e.code)) {
        return;
      }
      throw AppFailure(switch (e.code) {
        'email-already-in-use' => 'emailExists',
        'network-request-failed' => 'network',
        'too-many-requests' => 'rateLimit',
        'weak-password' => 'password',
        'operation-not-allowed' => 'service',
        'requires-recent-login' =>
          verification ? 'reauthenticate' : 'credentials',
        'user-token-expired' ||
        'invalid-user-token' ||
        'user-disabled' ||
        'user-not-found' => verification ? 'unauthorized' : 'credentials',
        'wrong-password' ||
        'invalid-credential' ||
        'user-mismatch' => 'credentials',
        _ => emailDispatch ? 'service' : 'credentials',
      });
    }
  }

  @override
  Future<void> login(String email, String password) => _perform(() async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<void> register(String email, String password) => _perform(() async {
    await _firebaseStep('create-account', () async {
      await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  });
  @override
  Future<bool> deleteUnverifiedRegistration(String uid) async {
    var deleted = false;
    await _perform(() async {
      final user = _user;
      if (user.uid != uid) throw const AppFailure('unauthorized');
      await user.reload();
      if (_user.uid != uid) throw const AppFailure('unauthorized');
      if (_user.emailVerified) return;
      await user.delete();
      // A different session must never be signed out by this registration.
      if (auth.currentUser != null && auth.currentUser!.uid != uid) {
        throw const AppFailure('unauthorized');
      }
      await auth.signOut();
      deleted = true;
    }, verification: true);
    return deleted;
  }

  @override
  Future<void> resetPassword(String email) => _perform(() async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }, reset: true);
  @override
  Future<void> logout() => _perform(auth.signOut);
}
