import 'package:firebase_auth/firebase_auth.dart';

import '../../guardian/data/guardian_repository.dart';

abstract class AuthService {
  bool get signedIn;
  Future<bool> restoreSession();
  Stream<bool> get changes;
  Future<void> login(String email, String password);
  Future<void> register(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> logout();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this.auth);
  final FirebaseAuth auth;
  @override
  bool get signedIn => auth.currentUser != null;
  @override
  Future<bool> restoreSession() async =>
      await auth.authStateChanges().first != null;
  @override
  Stream<bool> get changes => auth.authStateChanges().map((u) => u != null);
  Future<void> _perform(
    Future<void> Function() action, {
    bool reset = false,
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
        _ => 'credentials',
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
    await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<void> resetPassword(String email) => _perform(() async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }, reset: true);
  @override
  Future<void> logout() => _perform(auth.signOut);
}
