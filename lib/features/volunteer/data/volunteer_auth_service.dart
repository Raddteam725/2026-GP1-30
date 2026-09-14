import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../firebase_options.dart';
import '../domain/volunteer_models.dart';

class VolunteerAuthService {
  Future<FirebaseAuth> _auth() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirebaseAuth.instance;
  }

  Future<VolunteerAccount> signIn(String email, String password) async {
    final auth = await _auth();
    final result = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      final user = result.user!;
      final claims = (await user.getIdTokenResult(true)).claims ?? {};
      if (claims['role'] != 'volunteer' ||
          claims['enabled'] != true ||
          claims['volunteerId'] is! String ||
          (claims['volunteerId'] as String).isEmpty ||
          user.displayName == null ||
          user.displayName!.trim().isEmpty) {
        throw StateError('volunteer-required');
      }
      return VolunteerAccount(
        uid: user.uid,
        name: LocalizedData(user.displayName ?? '', user.displayName ?? ''),
        volunteerId: claims['volunteerId'] as String,
        active: true,
        email: user.email,
        phone: user.phoneNumber,
      );
    } catch (_) {
      await auth.signOut();
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await (await _auth()).sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
    }
  }

  Future<void> signOut() async {
    if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
  }
}
