import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/features/auth/data/auth_service.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  final calls = <String>[];
  String? failure;
  String? dispatchFailure;
  String? passwordFailure;
  String? reloadFailure, tokenFailure, exceptionMessage;
  bool reauthenticated = false;
  bool deleted = false;
  void Function()? afterReauthentication;
  @override
  String uid = 'same-uid';
  @override
  String email = 'typo@independent.example';
  @override
  bool emailVerified = false;
  @override
  Future<void> reload() async {
    calls.add('reload');
    if (reloadFailure != null) {
      throw FirebaseAuthException(code: reloadFailure!);
    }
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    calls.add('token:$forceRefresh');
    if (tokenFailure != null) throw FirebaseAuthException(code: tokenFailure!);
    return 'fresh-token';
  }

  @override
  Future<void> delete() async {
    calls.add('delete');
    deleted = true;
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    calls.add('send');
    final code = failure ?? dispatchFailure;
    if (code != null) {
      throw FirebaseAuthException(code: code, message: exceptionMessage);
    }
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    final password = credential as EmailAuthCredential;
    calls.add('reauth:${password.email}:${password.password}');
    if (failure != null) throw FirebaseAuthException(code: failure!);
    reauthenticated = true;
    afterReauthentication?.call();
    return _Credential();
  }

  @override
  Future<void> updatePassword(String password) async {
    calls.add('update-password');
    if (passwordFailure != null &&
        !(passwordFailure == 'requires-recent-login' && reauthenticated)) {
      throw FirebaseAuthException(code: passwordFailure!);
    }
  }

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? settings,
  ]) async {
    calls.add('verify-new:$newEmail');
    if (dispatchFailure != null) {
      throw FirebaseAuthException(
        code: dispatchFailure!,
        message: exceptionMessage,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firebase implements FirebaseAuth {
  _Firebase(this.currentUser);
  @override
  _User? currentUser;
  String? language;
  final languageChanges = <String?>[];
  final resetRequests = <(String, String?)>[];
  final creations = <(String, String)>[];
  String? creationFailure;
  int signOuts = 0;

  @override
  Future<void> signOut() async {
    signOuts++;
    currentUser = null;
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    creations.add((email, password));
    if (creationFailure != null) {
      throw FirebaseAuthException(code: creationFailure!);
    }
    currentUser = _User()..email = email;
    return _Credential();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw FirebaseAuthException(code: 'user-not-found');
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    languageChanges.add(languageCode);
    language = languageCode;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetRequests.add((email, language));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _User user;
  late _Firebase firebase;
  late FirebaseAuthService auth;
  setUp(() {
    user = _User();
    firebase = _Firebase(user);
    auth = FirebaseAuthService(firebase);
  });

  test('SDK creates an unverified signed-in account; send and refresh keep its UID', () async {
    firebase.currentUser = null;
    await auth.register(' new@example.test ', 'ValidPass1!');
    expect(firebase.creations, [('new@example.test', 'ValidPass1!')]);
    final created = firebase.currentUser!;
    expect(auth.signedIn, isTrue);
    expect(auth.currentIdentity!.emailVerified, isFalse);
    expect(created.calls, isEmpty);
    await auth.sendVerification('ar');
    expect(created.calls, ['send']);
    expect(auth.currentIdentity!.emailVerified, isFalse);
    created.emailVerified = true;
    final verified = await auth.refreshIdentity();
    expect(created.calls, ['send', 'reload', 'token:true']);
    expect(verified.uid, created.uid);
    expect(verified.emailVerified, isTrue);
    expect(firebase.languageChanges, isEmpty);
    expect(await auth.deleteUnverifiedRegistration(created.uid), isFalse);
    expect(created.deleted, isFalse);
    expect(firebase.signOuts, 0);
    created.emailVerified = false;
    await expectLater(
      auth.deleteUnverifiedRegistration('another-uid'),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'unauthorized')),
    );
    expect(created.deleted, isFalse);
    expect(await auth.deleteUnverifiedRegistration(created.uid), isTrue);
    expect(created.deleted, isTrue);
    expect(firebase.currentUser, isNull);
    expect(firebase.signOuts, 1);
  });

  for (final (sdkCode, code) in [
    ('email-already-in-use', 'emailExists'),
    ('weak-password', 'password'),
    ('network-request-failed', 'network'),
    ('too-many-requests', 'rateLimit'),
    ('operation-not-allowed', 'service'),
  ]) {
    test(
      'Registration maps $sdkCode without changing an existing account',
      () async {
        firebase.creationFailure = sdkCode;
        final before = auth.currentIdentity!;
        await expectLater(
          auth.register('new@example.test', 'NewPass1!'),
          throwsA(isA<AppFailure>().having((e) => e.code, 'code', code)),
        );
        expect(identical(firebase.currentUser, user), isTrue);
        expect(auth.currentIdentity!.uid, before.uid);
        expect(auth.currentIdentity!.email, before.email);
        expect(user.calls, isEmpty);
        expect(firebase.languageChanges, isEmpty);
      },
    );
  }

  test('Password update uses the existing UID without email verification or language mutation', () async {
    await auth.updatePassword('NewValidPass2!');
    expect(user.calls, ['update-password']);
    expect(user.uid, 'same-uid');
    expect(user.email, 'typo@independent.example');
    expect(user.emailVerified, isFalse);
    expect(firebase.languageChanges, isEmpty);
    expect(firebase.creations, isEmpty);
  });

  test('Password update reauthenticates actual current email when recent login is required', () async {
    user.passwordFailure = 'requires-recent-login';
    await expectLater(
      auth.updatePassword('NewValidPass2!'),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'reauthenticate'),
      ),
    );
    await auth.updatePassword(
      'NewValidPass2!',
      currentPassword: 'ExistingPass1!',
    );
    expect(user.calls, [
      'update-password',
      'reauth:typo@independent.example:ExistingPass1!',
      'update-password',
    ]);
    expect(user.uid, 'same-uid');
    expect(firebase.languageChanges, isEmpty);
  });

  for (final (sdk, code) in [
    ('weak-password', 'password'),
    ('network-request-failed', 'network'),
    ('too-many-requests', 'rateLimit'),
    ('user-token-expired', 'unauthorized'),
  ]) {
    test(
      'Password update failure $sdk preserves identity and existing error mapping',
      () async {
        user.passwordFailure = sdk;
        await expectLater(
          auth.updatePassword('NewValidPass2!'),
          throwsA(isA<AppFailure>().having((e) => e.code, 'code', code)),
        );
        expect(user.uid, 'same-uid');
        expect(user.email, 'typo@independent.example');
        expect(user.emailVerified, isFalse);
        expect(firebase.creations, isEmpty);
      },
    );
  }

  test('Wrong current password cannot reach password update', () async {
    user.failure = 'wrong-password';
    await expectLater(
      auth.updatePassword('NewValidPass2!', currentPassword: 'WrongPass1!'),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'credentials')),
    );
    expect(user.calls, ['reauth:typo@independent.example:WrongPass1!']);
  });

  test('Changed session UID during reauthentication cannot update another password', () async {
    user.afterReauthentication = () =>
        firebase.currentUser = _User()..uid = 'other-uid';
    await expectLater(
      auth.updatePassword('NewValidPass2!', currentPassword: 'ExistingPass1!'),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'unauthorized')),
    );
    expect(user.calls, ['reauth:typo@independent.example:ExistingPass1!']);
    expect(firebase.currentUser!.calls, isEmpty);
  });

  test(
    'Reload precedes forced token refresh; a cached verified flag never wins',
    () async {
      expect(auth.currentIdentity!.emailVerified, isFalse);
      final identity = await auth.refreshIdentity();
      expect(user.calls, ['reload', 'token:true']);
      expect(identity.emailVerified, isFalse);
      user.emailVerified = true;
      expect((await auth.refreshIdentity()).emailVerified, isTrue);
    },
  );
  test(
    'Verification uses Firebase email dispatch without overriding its language',
    () async {
      await auth.sendVerification('ar');
      expect(firebase.language, isNull);
      expect(firebase.languageChanges, isEmpty);
      expect(user.calls, ['send']);
      expect(user.emailVerified, isFalse);
    },
  );
  test('Email correction reauthenticates actual identity then verifies before update', () async {
    await auth.verifyNewEmail(
      ' corrected@custom.example ',
      'ExistingPass1!',
      'en',
    );
    expect(user.calls, [
      'reauth:typo@independent.example:ExistingPass1!',
      'verify-new:corrected@custom.example',
    ]);
    expect(user.email, 'typo@independent.example');
    expect(user.uid, 'same-uid');
    expect(user.emailVerified, isFalse);
    expect(firebase.language, isNull);
    expect(firebase.languageChanges, isEmpty);
  });
  for (final correction in [false, true]) {
    for (final language in ['en', 'ar']) {
      for (final originalLanguage in <String?>[null, 'fr']) {
        for (final fails in [false, true]) {
          test('SDK email preserves reset locale '
              '(correction=$correction, UI=$language, '
              'original=$originalLanguage, fails=$fails)', () async {
            firebase.language = originalLanguage;
            if (fails) user.dispatchFailure = 'network-request-failed';
            final request = correction
                ? auth.verifyNewEmail(
                    ' new@custom.example ',
                    'secret',
                    language,
                  )
                : auth.sendVerification(language);
            if (fails) {
              await expectLater(
                request,
                throwsA(
                  isA<AppFailure>().having((e) => e.code, 'code', 'network'),
                ),
              );
            } else {
              await request;
            }
            expect(
              user.calls,
              correction
                  ? [
                      'reauth:typo@independent.example:secret',
                      'verify-new:new@custom.example',
                    ]
                  : ['send'],
            );
            expect(firebase.languageChanges, isEmpty);
            expect(firebase.language, originalLanguage);
            await auth.resetPassword(' reset@custom.example ');
            expect(firebase.resetRequests, [
              ('reset@custom.example', originalLanguage),
            ]);
            expect(firebase.languageChanges, isEmpty);
            expect(user.email, 'typo@independent.example');
            expect(user.uid, 'same-uid');
            expect(user.emailVerified, isFalse);
          });
        }
      }
    }
  }
  for (final entry in {
    'wrong-password': 'credentials',
    'requires-recent-login': 'reauthenticate',
    'too-many-requests': 'rateLimit',
    'network-request-failed': 'network',
    'email-already-in-use': 'emailExists',
    'user-token-expired': 'unauthorized',
    'user-not-found': 'unauthorized',
  }.entries) {
    test(
      'Correction failure ${entry.key} never changes or duplicates the account',
      () async {
        user.failure = entry.key;
        await expectLater(
          auth.verifyNewEmail('new@custom.example', 'secret', 'en'),
          throwsA(isA<AppFailure>().having((e) => e.code, 'code', entry.value)),
        );
        expect(user.calls, ['reauth:typo@independent.example:secret']);
        expect(user.email, 'typo@independent.example');
        expect(user.uid, 'same-uid');
      },
    );
  }
  test(
    'No current Firebase account cannot refresh or send verification',
    () async {
      firebase.currentUser = null;
      await expectLater(auth.refreshIdentity(), throwsA(isA<AppFailure>()));
      await expectLater(
        auth.sendVerification('en'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'Existing login still hides missing-account details as invalid credentials',
    () async {
      await expectLater(
        auth.login('missing@custom.example', 'password'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'credentials')),
      );
    },
  );

  group('Verification diagnostics', () {
    late List<String> messages;
    late DebugPrintCallback originalPrint;
    setUp(() {
      messages = [];
      originalPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
    });
    tearDown(() => debugPrint = originalPrint);

    for (final correction in [false, true]) {
      test('Rejected dispatch retains exact safe code (correction=$correction)', () async {
        user.dispatchFailure = 'internal-error';
        user.exceptionMessage =
            'private-payload password token https://private.invalid/action';
        await expectLater(
          correction
              ? auth.verifyNewEmail(
                  'new@custom.example',
                  'ExistingPass1!',
                  'ar',
                )
              : auth.sendVerification('ar'),
          throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'service')),
        );
        final operation = correction
            ? 'verify-before-update-email'
            : 'send-email-verification';
        expect(
          messages,
          contains(
            'RaddAuth operation=$operation status=rejected code=internal-error',
          ),
        );
        expect(
          messages,
          isNot(contains('RaddAuth operation=$operation status=completed')),
        );
        final output = messages.join('\n');
        for (final sensitive in [
          user.email,
          user.uid,
          'new@custom.example',
          'ExistingPass1!',
          'private-payload',
          'https:',
          'fresh-token',
        ]) {
          expect(output, isNot(contains(sensitive)));
        }
        expect(user.emailVerified, isFalse);
        expect(firebase.creations, isEmpty);
        expect(firebase.languageChanges, isEmpty);
      });
    }

    test('Accepted ordinary resend reports SDK completion without reauthentication', () async {
      await auth.sendVerification('en');
      expect(messages, [
        'RaddAuth operation=send-email-verification status=requested',
        'RaddAuth operation=send-email-verification status=completed',
      ]);
      expect(user.calls, ['send']);
      expect(user.emailVerified, isFalse);
    });

    test(
      'Rejected correction reauthentication cannot dispatch to the new address',
      () async {
        user.failure = 'wrong-password';
        await expectLater(
          auth.verifyNewEmail('new@custom.example', 'WrongPass1!', 'en'),
          throwsA(
            isA<AppFailure>().having((e) => e.code, 'code', 'credentials'),
          ),
        );
        expect(
          messages,
          contains(
            'RaddAuth operation=reauthenticate-email-correction status=rejected code=wrong-password',
          ),
        );
        expect(messages.join(), isNot(contains('verify-before-update-email')));
        expect(messages.join(), isNot(contains('WrongPass1!')));
      },
    );

    for (final reload in [true, false]) {
      test('Refresh failure identifies the pre-send step (reload=$reload)', () async {
        if (reload) {
          user.reloadFailure = 'network-request-failed';
        } else {
          user.tokenFailure = 'network-request-failed';
        }
        await expectLater(auth.refreshIdentity(), throwsA(isA<AppFailure>()));
        final operation = reload ? 'reload' : 'refresh-token';
        expect(
          messages,
          contains(
            'RaddAuth operation=$operation status=rejected code=network-request-failed',
          ),
        );
        expect(user.calls, isNot(contains('send')));
      });
    }
  });
}
