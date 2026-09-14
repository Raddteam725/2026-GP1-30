import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../firebase_options.dart';

class VolunteerAuthService {
  Future<FirebaseAuth> _auth() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirebaseAuth.instance;
  }

  Future<void> signIn(String email, String password) async {
    final auth = await _auth();
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Authorization and the admin-owned profile are resolved by FastAPI.
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
