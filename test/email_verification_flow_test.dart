import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_router.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/core/theme/app_theme.dart';
import 'package:radd/features/auth/data/auth_service.dart';
import 'package:radd/features/auth/data/registration_draft.dart';
import 'package:radd/features/auth/presentation/auth_screen.dart';
import 'package:radd/features/auth/presentation/email_verification_screen.dart';
import 'package:radd/features/auth/presentation/session_screen.dart';
import 'package:radd/features/auth/presentation/verified_email_gate.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guardian_gate.dart';

import 'support/guardian_fakes.dart';

class _Auth extends TestAuth {
  _Auth() {
    emailVerified = false;
  }
  String? sendFailure, correctionFailure, refreshFailure;
  String? loginFailure, loginUid;
  bool verifiedOnLogin = false;
  bool refreshSignsOut = false;
  int loginAttempts = 0;
  Completer<void>? refreshPending;
  bool createdBeforeTransportError = false;
  @override
  Future<void> login(String email, String password) async {
    loginAttempts++;
    if (loginFailure != null) throw AppFailure(loginFailure!);
    await super.login(email, password);
    if (verifiedOnLogin) {
      refreshFailure = null;
      emailVerified = true;
    }
    if (loginUid != null) uid = loginUid!;
  }

  @override
  Future<void> register(String email, String password) async {
    await super.register(email, password);
    if (createdBeforeTransportError) throw const AppFailure('network');
  }

  @override
  Future<void> sendVerification(String language) async {
    await super.sendVerification(language);
    if (sendFailure != null) throw AppFailure(sendFailure!);
  }

  @override
  Future<void> verifyNewEmail(
    String email,
    String password,
    String language,
  ) async {
    await super.verifyNewEmail(email, password, language);
    if (correctionFailure != null) throw AppFailure(correctionFailure!);
  }

  @override
  Future<AuthIdentity> refreshIdentity() async {
    if (refreshPending != null) await refreshPending!.future;
    if (refreshSignsOut && refreshFailure == 'unauthorized') active = false;
    if (refreshFailure != null) throw AppFailure(refreshFailure!);
    return super.refreshIdentity();
  }
}

class _Repository extends TestRepository {
  bool exists = false, rejectProfile = false;
  String? rejectCode;
  String? roleFailure;
  String role = 'guardian';
  int writes = 0, reads = 0;
  @override
  Future<String> accountRole() async {
    if (roleFailure != null) throw AppFailure(roleFailure!);
    if (!exists) throw const AppFailure('notFound');
    return role;
  }

  @override
  Future<GuardianProfile> profile() async {
    reads++;
    return super.profile();
  }

  @override
  Future<GuardianProfile> createProfile(String name, String phone) async {
    writes++;
    if (rejectCode != null) throw AppFailure(rejectCode!);
    if (rejectProfile) throw const AppFailure('network');
    exists = true;
    return super.createProfile(name, phone);
  }
}

void main() {
  late _Auth auth;
  late _Repository repo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _Auth();
    repo = _Repository();
  });
  tearDown(() => auth.events.close());

  Future<void> mount(WidgetTester t, Widget screen, String language) async {
    t.view.physicalSize = const Size(800, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
    });
    await t.pumpWidget(
      AppServices(
        auth: auth,
        guardian: repo,
        child: MaterialApp(
          locale: Locale(language),
          theme: AppTheme.light(Locale(language)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.guardian ||
                settings.name == AppRoutes.volunteer) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    Scaffold(body: Text('Protected ${settings.name}')),
              );
            }
            return AppRouter.onGenerateRoute(settings);
          },
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> press(WidgetTester t, String label) async {
    final button = find.text(label);
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pumpAndSettle();
  }

  void background(WidgetTester t) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void resume(WidgetTester t) {
    if (t.binding.lifecycleState == AppLifecycleState.paused) {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }
    if (t.binding.lifecycleState != AppLifecycleState.inactive) {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    }
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  Future<void> fillRegistration(WidgetTester t, AppLocalizations s) async {
    final fields = find.byType(TextFormField);
    for (final (index, value) in [
      'Draft Guardian',
      'typo@custom.example',
      '0501234567',
      'ValidPass1!',
      'ValidPass1!',
    ].indexed) {
      await t.ensureVisible(fields.at(index));
      await t.enterText(fields.at(index), value);
    }
    for (var i = 0; i < 2; i++) {
      await t.ensureVisible(find.byType(CheckboxListTile).at(i));
      await t.tap(find.byType(CheckboxListTile).at(i));
      await t.pumpAndSettle();
    }
    await press(t, s.createAccount);
  }

  for (final language in ['en', 'ar']) {
    final s = lookupAppLocalizations(Locale(language));

    testWidgets(
      'Registration sends verification before any profile write in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        expect(find.text(s.registrationVerifyEmailTitle), findsOneWidget);
        expect(auth.verificationRequests, [language]);
        expect(auth.registrations, 1);
        expect(auth.emailVerified, isFalse);
        expect(repo.writes, 0);
        expect(repo.reads, 0);
        final draft = await RegistrationDraft.read(auth.uid);
        expect(draft['name'], 'Draft Guardian');
        expect(draft['phone'], '0501234567');
        expect(draft['adult'], isTrue);
        expect(draft['privacy'], isTrue);
        expect(draft.keys, isNot(contains('password')));
        expect(draft.keys, isNot(contains('emailVerified')));
        for (final field in t.widgetList<TextFormField>(
          find.byType(TextFormField),
        )) {
          expect(field.enabled, isFalse);
        }
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text(s.emailNotVerified), findsNothing);
        expect(repo.writes, 0);
        expect(auth.registrations, 1);
      },
    );

    testWidgets(
      'Verification resumes saved profile; failure retries same UID in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        auth.emailVerified = true; // Firebase accepted its verification link.
        repo.rejectProfile = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.byType(AuthScreen), findsOneWidget);
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(3));
        expect(
          t.widget<TextFormField>(fields.first).controller!.text,
          'Draft Guardian',
        );
        expect(
          t.widget<TextFormField>(fields.at(2)).controller!.text,
          '0501234567',
        );
        expect(find.text(s.networkError), findsOneWidget);
        expect(auth.registrations, 1);
        final uid = auth.uid;
        expect(repo.writes, 1);
        repo.rejectProfile = false;
        await press(t, s.createAccount);
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(auth.uid, uid);
        expect(auth.registrations, 1);
        expect(repo.writes, 2);
        expect(await RegistrationDraft.read(auth.uid), isEmpty);
      },
    );

    testWidgets(
      'Restart and protected deep link cannot bypass verification in $language',
      (t) async {
        auth.active = true;
        repo.exists = true;
        await mount(t, const GuardianGate(child: Text('SECRET')), language);
        expect(find.text('SECRET'), findsNothing);
        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        expect(repo.reads, 0);
        await t.pumpWidget(const SizedBox());
        await mount(t, const SessionScreen(), language);
        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        expect(
          auth.verificationRequests,
          isEmpty,
        ); // Restart never spams email.
        expect(repo.reads, 0);
        auth.emailVerified = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text('Protected /guardian'), findsOneWidget);
      },
    );

    testWidgets(
      'Verified missing-profile restart recollects required data without another Auth account in $language',
      (t) async {
        auth.active = true;
        auth.emailVerified = true;
        final uid = auth.uid;
        await mount(t, const SessionScreen(), language);
        await press(t, s.completeGuardianProfile);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        await press(t, s.save);
        expect(repo.writes, 0);
        expect(find.text(s.requiredField), findsWidgets);
        await t.enterText(fields.first, 'Recovered Guardian');
        await t.enterText(fields.last, '0501234567');
        for (var i = 0; i < 2; i++) {
          final box = find.byType(CheckboxListTile).at(i);
          await t.ensureVisible(box);
          await t.tap(box);
        }
        await press(t, s.save);
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(auth.uid, uid);
        expect(auth.registrations, 0);
        expect(repo.writes, 1);
        expect(repo.person.fullName, 'Recovered Guardian');
      },
    );

    testWidgets(
      'Changed signed-in UID cannot finish the pending registration in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        auth.uid = 'different-account';
        auth.emailVerified = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text(s.sessionExpired), findsOneWidget);
        expect(repo.writes, 0);
        expect(auth.registrations, 1);
      },
    );

    testWidgets(
      'Pending corrected email also blocks direct onboarding after restart in $language',
      (t) async {
        auth.active = true;
        auth.emailVerified = true;
        await RegistrationDraft.update(auth.uid, {
          'pendingEmail': 'pending@example.test',
        });
        await mount(
          t,
          const VerifiedEmailGate(child: Text('PROFILE FORM')),
          language,
        );
        expect(find.text('PROFILE FORM'), findsNothing);
        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text(s.emailNotVerified), findsNothing);
        expect(repo.writes, 0);
      },
    );

    testWidgets('Resend cooldown persists across screen restart in $language', (
      t,
    ) async {
      auth.active = true;
      await mount(t, const EmailVerificationScreen(), language);
      await press(t, s.registrationResendLink);
      expect(auth.verificationRequests, [language]);
      expect(find.textContaining(s.registrationLinkSent), findsOneWidget);
      expect(
        find.text(
          '${s.registrationResendLink} (${s.verificationCooldown(60)})',
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      await mount(t, const EmailVerificationScreen(), language);
      expect(
        find.text(
          '${s.registrationResendLink} (${s.verificationCooldown(60)})',
        ),
        findsOneWidget,
      );
      expect(auth.verificationRequests, [language]);
      await t.pumpWidget(const SizedBox());
      await RegistrationDraft.update(auth.uid, {
        'resendAt': DateTime.now()
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      });
      await mount(t, const EmailVerificationScreen(), language);
      await press(t, s.registrationResendLink);
      expect(auth.verificationRequests, [language, language]);
    });

    testWidgets(
      'Wrong-email recovery opens an empty Create Account form without UI-only changes in $language',
      (t) async {
        auth.active = true;
        auth.email = 'typo@custom.example';
        await mount(t, const EmailVerificationScreen(), language);
        expect(find.byType(TextButton), findsNWidgets(2));
        expect(find.byType(TextFormField), findsNothing);
        await press(t, s.registrationEditInformation);
        expect(auth.signedIn, isFalse);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(
          t.widget<AuthScreen>(find.byType(AuthScreen)).mode,
          AuthMode.register,
        );
        expect(find.byType(BackButton), findsOneWidget);
        for (final field in t.widgetList<TextFormField>(
          find.byType(TextFormField),
        )) {
          expect(field.controller!.text, isEmpty);
        }
        expect(auth.emailCorrections, isEmpty);
        expect(auth.registrations, 0);
        expect(repo.writes, 0);
      },
    );

    testWidgets(
      'Email request and reload network failures recover in $language',
      (t) async {
        auth.active = true;
        auth.sendFailure = 'network';
        await mount(
          t,
          const EmailVerificationScreen(sendOnOpen: true),
          language,
        );
        expect(find.text(s.networkError), findsOneWidget);
        expect(repo.writes, 0);
        auth.sendFailure = null;
        await press(t, s.registrationResendLink);
        expect(find.textContaining(s.registrationLinkSent), findsOneWidget);
        auth.refreshFailure = 'network';
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text(s.networkError), findsNothing);
        auth.refreshFailure = null;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text(s.emailNotVerified), findsNothing);
        expect(repo.writes, 0);
      },
    );

    testWidgets(
      'Missing-profile restart and direct onboarding stay gated in $language',
      (t) async {
        auth.active = true;
        await mount(t, const SessionScreen(), language);
        // A missing role is ambiguous: preserve the original recovery choice.
        expect(find.byType(EmailVerificationScreen), findsNothing);
        await press(t, s.completeGuardianProfile);
        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        expect(repo.writes, 0);
        final context = t.element(find.byType(EmailVerificationScreen));
        Navigator.of(context).pushNamed(AppRoutes.completeProfile);
        await t.pumpAndSettle();
        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        expect(find.byType(AuthScreen), findsNothing);
      },
    );

    testWidgets(
      'Firebase resend throttling keeps the account blocked in $language',
      (t) async {
        auth.active = true;
        auth.sendFailure = 'rateLimit';
        await mount(t, const EmailVerificationScreen(), language);
        await press(t, s.registrationResendLink);
        expect(find.text(s.rateLimit), findsOneWidget);
        expect(
          t
              .widget<TextButton>(
                find.widgetWithText(TextButton, s.registrationResendLink),
              )
              .onPressed,
          isNotNull,
        );
        expect(auth.verificationRequests, [language]);
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(repo.writes, 0);
      },
    );

    testWidgets(
      'Existing expired session Edit signs out without deleting in $language',
      (t) async {
        auth.active = true;
        auth.refreshFailure = 'unauthorized';
        await mount(t, const EmailVerificationScreen(), language);
        expect(find.text(s.sessionExpired), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(TextButton), findsNWidgets(2));
        await press(t, s.registrationEditInformation);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(auth.signedIn, isFalse);
        expect(auth.registrations, 0);
        expect(repo.writes, 0);
        expect(
          t.widget<AuthScreen>(find.byType(AuthScreen)).mode,
          AuthMode.register,
        );
      },
    );

    testWidgets(
      'Returning from the Firebase link finalizes once on a small screen in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        final uid = auth.uid;
        t.view.physicalSize = const Size(360, 640);
        await t.pumpAndSettle();
        expect(find.text(s.createTitle), findsOneWidget);
        expect(find.text(s.createHint), findsOneWidget);
        expect(find.text(s.registrationEditTitle), findsNothing);
        expect(find.text(s.registrationPendingAccount), findsNothing);
        expect(find.widgetWithText(FilledButton, s.createAccount), findsOneWidget);
        expect(find.widgetWithText(FilledButton, s.save), findsNothing);
        background(t);
        auth.emailVerified = true;
        resume(t);
        resume(t);
        await t.pumpAndSettle();
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(repo.writes, 1);
        expect(auth.uid, uid);
        expect(auth.registrations, 1);
        expect(auth.logins, 0);
        expect(auth.verificationRequests, [language]);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'Unverified app resume is informational and never resends in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        background(t);
        resume(t);
        await t.pumpAndSettle();
        expect(find.text(s.emailNotVerified), findsNothing);
        expect(find.text(s.registrationSessionSignIn), findsNothing);
        expect(auth.verificationRequests, [language]);
        expect(repo.writes, 0);
      },
    );

    testWidgets(
      'Overlapping resume checks cannot repeat profile finalization in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        auth.refreshPending = Completer<void>();
        resume(t);
        await t.pump();
        resume(t);
        auth.emailVerified = true;
        auth.refreshPending!.complete();
        await t.pumpAndSettle();
        expect(repo.writes, 1);
        expect(auth.registrations, 1);
        expect(find.text('Protected /guardian'), findsOneWidget);
      },
    );

    testWidgets(
      'Guardian login hint cannot redirect a resolved Volunteer in $language',
      (t) async {
        repo.exists = true;
        repo.role = 'volunteer';
        await mount(t, const AuthScreen(), language);
        await t.enterText(find.byType(TextFormField).first, auth.email);
        await t.enterText(find.byType(TextFormField).last, 'ExistingPass1!');
        await press(t, s.login);
        expect(find.text('Protected /volunteer'), findsOneWidget);
        expect(auth.identityRefreshes, 0);
        expect(repo.writes, 0);
        expect(auth.registrations, 0);
      },
    );

    testWidgets(
      'Profile completion never restores another UID draft in $language',
      (t) async {
        auth.active = true;
        auth.emailVerified = true;
        await RegistrationDraft.update('another-uid', {
          'registrationPending': true,
          'name': 'Someone Else',
          'phone': '0501234567',
          'adult': true,
          'privacy': true,
        });
        await mount(t, const SessionScreen(guardianLogin: true), language);
        expect(find.text('Someone Else'), findsNothing);
        expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          isEmpty,
        );
        expect(repo.writes, 0);
      },
    );

    testWidgets(
      'Verified UID restores its own pending registration directly to Home in $language',
      (t) async {
        auth.active = true;
        auth.emailVerified = true;
        await RegistrationDraft.update(auth.uid, {
          'registrationPending': true,
          'name': 'Restored Guardian',
          'phone': '0501234567',
          'adult': true,
          'privacy': true,
        });
        await mount(t, const SessionScreen(), language);
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(find.text(s.sessionRecovery), findsNothing);
        expect(repo.person.fullName, 'Restored Guardian');
        expect(repo.writes, 1);
        expect(auth.registrations, 0);
        expect(await RegistrationDraft.read(auth.uid), isEmpty);
      },
    );

    testWidgets(
      'An unchecked declaration still blocks edited registration in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        await press(t, s.registrationEditInformation);
        expect(auth.signedIn, isFalse);
        await t.ensureVisible(find.byType(CheckboxListTile).last);
        await t.tap(find.byType(CheckboxListTile).last);
        await t.pumpAndSettle();
        await press(t, s.createAccount);
        expect(auth.registrations, 1);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(repo.writes, 0);
        expect(
          t.widget<CheckboxListTile>(find.byType(CheckboxListTile).last).value,
          isFalse,
        );
      },
    );

    testWidgets(
      'Guardian login with genuinely missing data opens only profile completion in $language',
      (t) async {
        auth.emailVerified = true;
        await mount(t, const AuthScreen(), language);
        final login = find.byType(TextFormField);
        await t.enterText(login.first, auth.email);
        await t.enterText(login.last, 'ExistingPass1!');
        await press(t, s.login);
        expect(find.text(s.sessionRecovery), findsNothing);
        expect(find.text(s.createTitle), findsNothing);
        expect(find.text(s.returnToRoles), findsNothing);
        expect(find.byType(TextFormField), findsNWidgets(2));
        await t.enterText(
          find.byType(TextFormField).first,
          'Existing Guardian',
        );
        await t.enterText(find.byType(TextFormField).last, '0501234567');
        for (var i = 0; i < 2; i++) {
          await t.ensureVisible(find.byType(CheckboxListTile).at(i));
          await t.tap(find.byType(CheckboxListTile).at(i));
          await t.pumpAndSettle();
        }
        await press(t, s.save);
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(auth.registrations, 0);
        expect(repo.writes, 1);
      },
    );

    testWidgets(
      'Expired corrected-email session shows only an error and and finishes the same UID in $language',
      (t) async {
        auth.active = true;
        final uid = auth.uid;
        auth.refreshFailure = 'unauthorized';
        await mount(t, const EmailVerificationScreen(), language);
        expect(find.text(s.sessionExpired), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.widgetWithText(FilledButton, s.login), findsNothing);
        await t.pump(const Duration(seconds: 6));
        await t.pumpAndSettle();
        expect(auth.loginAttempts, 0);
        expect(auth.uid, uid);
        expect(repo.writes, 0);
        auth.refreshFailure = null;
        auth.emailVerified = true;
        repo.exists = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(auth.registrations, 0);
      },
    );

    testWidgets(
      'Recovery cannot adopt a different signed-in UID in $language',
      (t) async {
        auth.active = true;
        await mount(t, const EmailVerificationScreen(), language);
        auth.uid = 'other-uid';
        auth.emailVerified = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(find.text(s.sessionExpired), findsOneWidget);
        await press(t, s.registrationEditInformation);
        expect(auth.signedIn, isTrue);
        expect(auth.uid, 'other-uid');
        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        expect(repo.writes, 0);
        expect(auth.registrations, 0);
      },
    );

    testWidgets(
      'Expired edit session keeps its pinned identity when Firebase clears currentUser in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t, s);
        auth.refreshSignsOut = true;
        auth.refreshFailure = 'unauthorized';
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(auth.currentIdentity, isNull);
        expect(find.text(s.sessionExpired), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextFormField),
          ),
          findsNothing,
        );
        await press(t, s.registrationEditInformation);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(auth.registrations, 1);
        expect(auth.logins, 0);
        expect(repo.writes, 0);
      },
    );

    testWidgets(
      'Unauthorized Guardian startup keeps original recovery and retries its draft in $language',
      (t) async {
        auth.active = true;
        auth.refreshFailure = 'unauthorized';
        repo.roleFailure = 'unauthorized';
        await RegistrationDraft.update(auth.uid, {
          'registrationPending': true,
          'name': 'Resumed Guardian',
          'phone': '0501234567',
          'adult': true,
          'privacy': true,
        });
        await mount(t, const SessionScreen(), language);
        expect(find.text(s.sessionRecovery), findsOneWidget);
        expect(find.text(s.expiredSessionRecovery), findsOneWidget);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(TextButton), findsNWidgets(2));
        auth.refreshFailure = null;
        auth.emailVerified = true;
        repo.roleFailure = null;
        await press(t, s.retry);
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(repo.writes, 1);
        expect(auth.logins, 0);
        expect(auth.registrations, 0);
      },
    );

    testWidgets(
      'Expired Volunteer startup keeps its existing recovery in $language',
      (t) async {
        auth.active = true;
        repo.roleFailure = 'unauthorized';
        await mount(
          t,
          const SessionScreen(expectedRole: 'volunteer'),
          language,
        );
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(find.text(s.sessionRecovery), findsOneWidget);
        expect(auth.identityRefreshes, 0);
        expect(repo.writes, 0);
      },
    );

    testWidgets(
      'Restored correction rejects old verified email until new address verifies in $language',
      (t) async {
        auth.active = true;
        auth.emailVerified = true;
        await RegistrationDraft.update(auth.uid, {
          'registrationPending': true,
          'name': 'Pending Guardian',
          'phone': '0501234567',
          'adult': true,
          'privacy': true,
          'pendingEmail': 'new@custom.example',
        });
        await mount(t, const SessionScreen(), language);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(find.text(s.sessionRecovery), findsOneWidget);
        expect(repo.writes, 0);
        resume(t);
        await t.pumpAndSettle();
        expect(repo.writes, 0);
        auth.email = 'new@custom.example';
        await press(t, s.retry);
        expect(find.text('Protected /guardian'), findsOneWidget);
        expect(repo.writes, 1);
      },
    );

    for (final code in ['network', 'service', 'validation']) {
      testWidgets(
        'Finalization shows $code and retries the same profile in $language',
        (t) async {
          await mount(t, const AuthScreen(mode: AuthMode.register), language);
          await fillRegistration(t, s);
          repo.rejectCode = code;
          auth.emailVerified = true;
          resume(t);
          await t.pumpAndSettle();
          final message = code == 'network'
              ? s.networkError
              : code == 'validation'
              ? s.validationError
              : s.serviceError;
          expect(find.text(message), findsOneWidget);
          expect(find.text(s.sessionRecovery), findsNothing);
          expect(repo.writes, 1);
          expect(
            (await RegistrationDraft.read(auth.uid))['registrationPending'],
            isTrue,
          );
          repo.rejectCode = null;
          await press(t, s.createAccount);
          expect(find.text('Protected /guardian'), findsOneWidget);
          expect(repo.writes, 2);
          expect(auth.registrations, 1);
        },
      );
    }
  }

  testWidgets(
    'Visible cooldown ticks and enables resend on resume at its deadline',
    (t) async {
      auth.active = true;
      final s = lookupAppLocalizations(const Locale('en'));
      await RegistrationDraft.update(auth.uid, {
        'resendAt': DateTime.now()
            .add(const Duration(seconds: 3))
            .toIso8601String(),
      });
      await mount(t, const EmailVerificationScreen(), 'en');
      final initial = t.widget<TextButton>(
        find.widgetWithText(
          TextButton,
          '${s.registrationResendLink} (${s.verificationCooldown(3)})',
        ),
      );
      expect(initial.onPressed, isNull);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await t.pump(const Duration(seconds: 1));
      expect(
        find.text('${s.registrationResendLink} (${s.verificationCooldown(2)})'),
        findsOneWidget,
      );
      background(t);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2100)),
      );
      resume(t);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, s.registrationResendLink),
            )
            .onPressed,
        isNotNull,
      );
      expect(auth.verificationRequests, isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Ambiguous SDK creation reports an error without sending or opening a popup',
    (t) async {
      auth.createdBeforeTransportError = true;
      final s = lookupAppLocalizations(const Locale('en'));
      await mount(t, const AuthScreen(mode: AuthMode.register), 'en');
      await fillRegistration(t, s);
      expect(auth.registrations, 1);
      expect(find.text(s.networkError), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.verificationRequests, isEmpty);
      expect(repo.writes, 0);
      expect(auth.signedIn, isTrue);
    },
  );

  testWidgets(
    'Unverified Volunteer session retains server-owned role behavior',
    (t) async {
      auth.active = true;
      repo.exists = true;
      repo.role = 'volunteer';
      await mount(t, const SessionScreen(), 'en');
      expect(find.text('Protected /volunteer'), findsOneWidget);
      expect(repo.reads, 0);
      expect(auth.identityRefreshes, 0);
    },
  );

  test('Onboarding drafts are UID-scoped, expire on read, and contain no credentials', () async {
    await RegistrationDraft.update(auth.uid, {
      'name': 'Draft',
      'phone': '0501234567',
    });
    expect(await RegistrationDraft.read('other-uid'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'radd.registration.${auth.uid}',
      '{"name":"Expired","savedAt":"2000-01-01T00:00:00Z"}',
    );
    expect(await RegistrationDraft.read(auth.uid), isEmpty);
    expect(prefs.getString('radd.registration.${auth.uid}'), isNull);
  });
}
