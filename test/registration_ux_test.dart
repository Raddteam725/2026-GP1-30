import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/core/theme/app_colors.dart';
import 'package:radd/shared/widgets/password_input.dart';
import 'package:radd/core/theme/app_theme.dart';
import 'package:radd/features/auth/presentation/auth_screen.dart';
import 'package:radd/features/auth/data/auth_service.dart';
import 'package:radd/features/auth/data/registration_draft.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/edit_guardian_profile_screen.dart';

import 'support/guardian_fakes.dart';

import 'package:radd/core/routing/app_router.dart';

class _RegistrationAuth extends TestAuth {
  final attempts = <(String, String)>[];
  Completer<void>? pending;
  String? registrationFailure, sendFailure;
  Completer<void>? sendPending;
  Completer<void>? refreshPending;
  int checks = 0;
  bool rejectLogout = false;
  bool collisionSession = false;
  String? correctionFailure, passwordFailure;

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
  Future<void> updatePassword(
    String password, {
    String? currentPassword,
  }) async {
    await super.updatePassword(password, currentPassword: currentPassword);
    if (passwordFailure != null &&
        !(passwordFailure == 'reauthenticate' && currentPassword != null)) {
      throw AppFailure(passwordFailure!);
    }
  }

  @override
  Future<void> logout() async {
    if (rejectLogout) throw const AppFailure('network');
    await super.logout();
  }

  @override
  Future<void> sendVerification(String language) async {
    await super.sendVerification(language);
    if (sendPending != null) await sendPending!.future;
    if (sendFailure != null) throw AppFailure(sendFailure!);
  }

  @override
  Future<AuthIdentity> refreshIdentity() async {
    checks++;
    if (refreshPending != null) await refreshPending!.future;
    return super.refreshIdentity();
  }

  @override
  Future<void> register(String email, String password) async {
    attempts.add((email, password));
    if (pending != null) await pending!.future;
    if (registrationFailure != null) {
      if (collisionSession) {
        active = true;
        this.email = email.trim();
        uid = 'existing-account';
      }
      throw AppFailure(registrationFailure!);
    }
    await super.register(email, password);
  }
}

class _ProfileRepository extends TestRepository {
  final attempts = <(String, String)>[];
  Completer<void>? pending;
  bool reject = false;

  @override
  Future<GuardianProfile> createProfile(String name, String phone) async {
    attempts.add((name, phone));
    if (pending != null) await pending!.future;
    if (reject) throw const AppFailure('network');
    return super.createProfile(name, phone);
  }
}

void main() {
  late _RegistrationAuth auth;
  late _ProfileRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = _RegistrationAuth();
    repo = _ProfileRepository();
  });
  tearDown(() => auth.events.close());

  Future<void> mount(WidgetTester t, Widget screen, String language) async {
    t.view.physicalSize = const Size(800, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(() => t.pumpWidget(const SizedBox()));
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
            if (settings.name != AppRoutes.session) {
              return AppRouter.onGenerateRoute(settings);
            }
            expect(settings.arguments, anyOf(isNull, 'guardian'));
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Session destination')),
            );
          },
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> edit(WidgetTester t, Finder field, String value) async {
    await t.ensureVisible(field);
    await t.enterText(field, value);
    await t.pumpAndSettle();
  }

  void expectEnabled(WidgetTester t, bool enabled) {
    for (final field in t.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, enabled);
    }
  }

  void expectRedError(WidgetTester t, Finder field, String message) {
    final error = find.descendant(of: field, matching: find.text(message));
    expect(error, findsOneWidget);
    final text = t.widget<Text>(error);
    final style = DefaultTextStyle.of(t.element(error)).style.merge(text.style);
    expect(style.color, AppColors.error);
    // Inspect the resolved painted border, including Flutter's theme fallback.
    final paints = t.widgetList<CustomPaint>(
      find.descendant(of: field, matching: find.byType(CustomPaint)),
    );
    final dynamic painter = paints
        .map((paint) => paint.foregroundPainter)
        .singleWhere((p) => p.runtimeType.toString() == '_InputBorderPainter');
    final border =
        painter.border.evaluate(painter.borderAnimation) as InputBorder;
    expect(border.borderSide.style, BorderStyle.solid);
    expect(border.borderSide.color, AppColors.error);
  }

  Future<void> fillRegistration(WidgetTester t) async {
    final fields = find.byType(TextFormField);
    final values = [
      'Test Guardian',
      'guardian@independent.example',
      '0501234567',
      'ValidPass1!',
      'ValidPass1!',
    ];
    for (var i = 0; i < values.length; i++) {
      await edit(t, fields.at(i), values[i]);
    }
    for (var i = 0; i < 2; i++) {
      final checkbox = find.byType(CheckboxListTile).at(i);
      await t.ensureVisible(checkbox);
      await t.pumpAndSettle();
      await t.tap(checkbox);
      await t.pumpAndSettle();
    }
  }

  Future<void> submit(WidgetTester t, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    // Pending requests deliberately remain unresolved in the failure tests.
    await t.pump();
  }

  Future<void> pressText(WidgetTester t, String label) async {
    final button = find.widgetWithText(TextButton, label);
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    final s = lookupAppLocalizations(Locale(language));

    testWidgets(
      'Welcome Back retains its links; signup uses ordinary back in $language',
      (t) async {
        await mount(t, const AuthScreen(), language);
        expect(find.text(s.welcomeBack), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, s.forgotPassword),
          findsOneWidget,
        );
        final create = find.widgetWithText(TextButton, s.createAccount);
        await t.ensureVisible(create);
        await t.tap(create);
        await t.pumpAndSettle();
        expect(find.text(s.alreadyAccount), findsNothing);
        expect(find.widgetWithText(TextButton, s.login), findsNothing);
        expect(find.widgetWithText(TextButton, s.forgotPassword), findsNothing);
        expect(find.byType(TextFormField), findsNWidgets(5));
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(find.text(s.welcomeBack), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, s.forgotPassword),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, s.createAccount),
          findsOneWidget,
        );
        expect(auth.registrations, 0);
        expect(auth.verificationRequests, isEmpty);
      },
    );

    testWidgets(
      'Verification modal fits a small screen and keyboard with locale direction in $language',
      (t) async {
        await mount(t, const AuthScreen(), language);
        await pressText(t, s.createAccount);
        await fillRegistration(t);
        t.view.physicalSize = const Size(360, 640);
        await t.pumpAndSettle();
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        final dialog = find.byKey(
          const ValueKey('registration-verification-dialog'),
        );
        expect(dialog, findsOneWidget);
        expect(
          Directionality.of(t.element(dialog)),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          find.descendant(of: dialog, matching: find.byType(TextButton)),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: dialog, matching: find.byType(TextFormField)),
          findsNothing,
        );
        expect(
          find.widgetWithText(FilledButton, s.checkEmailVerification),
          findsNothing,
        );
        await t.tapAt(const Offset(2, 2));
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(dialog, findsOneWidget);
        await pressText(t, s.registrationEditInformation);
        expect(dialog, findsNothing);
        expect(auth.signedIn, isFalse);
        expect(find.byType(BackButton), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(5));
        expectEnabled(t, true);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(dialog, findsOneWidget);
        expect(auth.registrations, 2);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'Automatic verification skips overlapping checks and completes once in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        auth.emailVerified = true;
        auth.refreshPending = Completer<void>();
        repo.pending = Completer<void>();
        final previousChecks = auth.checks;
        await t.pump(const Duration(seconds: 3));
        await t.pump(const Duration(seconds: 6));
        expect(auth.checks, previousChecks + 1);
        expect(repo.attempts, isEmpty);
        expect(find.text(s.verificationChecking), findsNothing);
        auth.refreshPending!.complete();
        await t.pump();
        await t.pump();
        expect(repo.attempts, hasLength(1));
        await t.pump(const Duration(seconds: 6));
        expect(repo.attempts, hasLength(1));
        repo.pending!.complete();
        await t.pumpAndSettle();
        expect(auth.registrations, 1);
        expect(find.text('Session destination'), findsOneWidget);
      },
    );

    testWidgets(
      'Verification failure stays in the same modal and safely retries in $language',
      (t) async {
        auth.sendFailure = 'network';
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(find.text(s.networkError), findsOneWidget);
        final uid = auth.uid;
        expectEnabled(t, false);
        auth.sendFailure = null;
        final resend = find.widgetWithText(
          TextButton,
          s.registrationResendLink,
        );
        await t.ensureVisible(resend);
        await t.tap(resend);
        await t.pumpAndSettle();
        expect(auth.verificationRequests, [language, language]);
        expect(find.textContaining(s.registrationLinkSent), findsOneWidget);
        auth.emailVerified = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        await t.pumpAndSettle();
        expect(auth.uid, uid);
        expect(auth.registrations, 1);
        expect(find.text('Session destination'), findsOneWidget);
      },
    );

    testWidgets(
      'Disposing signup removes only its verification modal in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        final navigator = Navigator.of(t.element(find.byType(AuthScreen)));
        navigator.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Other destination')),
          ),
          (_) => false,
        );
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Other destination'), findsOneWidget);
        expect(t.takeException(), isNull);
        expect(repo.attempts, isEmpty);
      },
    );

    testWidgets(
      'Firebase verifies before profile creation and completes the original form in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expectEnabled(t, false);
        expect(auth.registrations, 1);
        expect(auth.signedIn, isTrue);
        expect(auth.verificationRequests, [language]);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(
              '${s.registrationLinkSent} guardian@independent.example',
            ),
          ),
          findsOneWidget,
        );
        expect(repo.attempts, isEmpty);
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        await t.pumpAndSettle();
        expect(find.text(s.emailNotVerified), findsNothing);
        expect(repo.attempts, isEmpty);
        auth.emailVerified = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        await t.pumpAndSettle();
        expect(auth.registrations, 1);
        expect(auth.logins, 0);
        expect(repo.attempts.single, ('Test Guardian', '0501234567'));
        expect(find.text('Session destination'), findsOneWidget);
      },
    );

    testWidgets(
      'Registration helper/error exclusivity and red borders in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        final fields = find.byType(TextFormField);
        final phone = fields.at(2), password = fields.at(3);
        expect(find.text(s.phoneHelp), findsOneWidget);
        expect(find.text(s.passwordHelp), findsOneWidget);
        await edit(t, phone, '123');
        expect(find.text(s.phoneHelp), findsNothing);
        expect(find.text(s.invalidPhone), findsOneWidget);
        expectRedError(t, phone, s.invalidPhone);
        await t.tap(fields.first);
        await t.pumpAndSettle();
        expectRedError(
          t,
          phone,
          s.invalidPhone,
        ); // Unfocused border is also red.
        await edit(t, phone, '0501234567');
        expect(find.text(s.invalidPhone), findsNothing);
        expect(find.text(s.phoneHelp), findsOneWidget);
        await edit(t, password, 'weak');
        expect(
          find.text(s.passwordHelp),
          findsOneWidget,
        ); // Error, not a duplicate helper.
        expectRedError(t, password, s.passwordHelp);
        await t.tap(fields.first);
        await t.pumpAndSettle();
        expectRedError(t, password, s.passwordHelp);
        await edit(t, password, '');
        expect(find.text(s.passwordHelp), findsNothing);
        expectRedError(t, password, s.requiredField);
        await edit(t, password, 'ValidPass1!');
        expect(t.state<FormFieldState<String>>(password).errorText, isNull);
        expect(find.text(s.passwordHelp), findsOneWidget);
        final helper = find.text(s.passwordHelp);
        final helperText = t.widget<Text>(helper);
        expect(
          DefaultTextStyle.of(t.element(helper)).style
              .merge(helperText.style)
              .color,
          isNot(AppColors.error),
        );
        expect(auth.attempts, isEmpty);
      },
    );

    for (final editing in [false, true]) {
      testWidgets(
        'Phone guidance yields to one error (editing=$editing) in $language',
        (t) async {
          await mount(
            t,
            editing
                ? EditGuardianProfileScreen(profile: repo.person)
                : const AuthScreen(mode: AuthMode.completeProfile),
            language,
          );
          final phone = find.byType(TextFormField).last;
          expect(find.text(s.phoneHelp), findsOneWidget);
          await edit(t, phone, 'invalid');
          expect(find.text(s.phoneHelp), findsNothing);
          expect(find.text(s.invalidPhone), findsOneWidget);
          expectRedError(t, phone, s.invalidPhone);
          await edit(t, phone, '');
          expect(find.text(s.phoneHelp), findsNothing);
          expectRedError(t, phone, s.requiredField);
          await edit(t, phone, '٠٥٠١٢٣٤٥٦٧');
          expect(find.text(s.requiredField), findsNothing);
          expect(find.text(s.phoneHelp), findsOneWidget);
        },
      );
    }

    testWidgets(
      'Invalid registration leaves every field editable in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expectEnabled(t, true);
        expect(auth.attempts, isEmpty);
        expect(repo.attempts, isEmpty);
        expect(find.text(s.phoneHelp), findsNothing);
        expect(find.text(s.passwordHelp), findsNothing);
        final fields = find.byType(TextFormField);
        for (var i = 0; i < 5; i++) {
          expectRedError(t, fields.at(i), s.requiredField);
        }
        await edit(t, fields.at(1), 'bad@');
        expectRedError(t, fields.at(1), s.invalidEmail);
        for (final email in [
          'guardian@independent.example',
          'guardian+tag@another.example',
          'guardian@gnail.com', // A syntax-valid typo does not prove ownership.
        ]) {
          await edit(t, fields.at(1), email);
          expect(
            t.state<FormFieldState<String>>(fields.at(1)).errorText,
            isNull,
          );
        }
        await edit(t, fields.at(3), 'NewValid2!');
        await edit(t, fields.at(4), 'NewValid2!');
        expectEnabled(t, true);
        expect(auth.attempts, isEmpty);
      },
    );

    for (final code in ['service', 'network']) {
      testWidgets(
        'Registration request failure $code unlocks credentials in $language',
        (t) async {
          auth.pending = Completer<void>();
          await mount(t, const AuthScreen(mode: AuthMode.register), language);
          await fillRegistration(t);
          await submit(t, s.createAccount);
          expectEnabled(t, false);
          expect(auth.attempts, hasLength(1));
          auth.pending!.completeError(AppFailure(code));
          await t.pumpAndSettle();
          expectEnabled(t, true);
          expect(auth.signedIn, isFalse);
          expect(repo.attempts, isEmpty);
          expect(
            find.text(code == 'service' ? s.serviceError : s.networkError),
            findsOneWidget,
          );
          final fields = find.byType(TextFormField);
          await edit(t, fields.at(1), 'corrected@another.example');
          await edit(t, fields.at(3), 'CorrectedPass2!');
          await edit(t, fields.at(4), 'CorrectedPass2!');
          auth.pending = Completer<void>();
          await submit(t, s.createAccount);
          expect(auth.attempts.last.$1, 'corrected@another.example');
          expect(auth.attempts, hasLength(2));
          auth.pending!.completeError(const AppFailure('network'));
          await t.pumpAndSettle();
          expectEnabled(t, true);
          expect(repo.attempts, isEmpty);
        },
      );
    }

    testWidgets(
      'Profile failure preserves real credentials and retries without registering again in $language',
      (t) async {
        repo.pending = Completer<void>();
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        auth.emailVerified = true;
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 3));
        await t.pump();
        await t.pump();
        expect(auth.signedIn, isTrue);
        expect(auth.registrations, 1);
        expect(repo.attempts, hasLength(1));
        repo.pending!.completeError(const AppFailure('network'));
        await t.pumpAndSettle();
        expect(find.text(s.networkError), findsOneWidget);
        expect(find.text(s.createTitle), findsOneWidget);
        expect(find.text(s.createHint), findsOneWidget);
        expect(find.text(s.registrationPendingAccount), findsNothing);
        final fields = find.byType(TextFormField);
        expect(t.widget<TextFormField>(fields.at(0)).enabled, isTrue);
        expect(t.widget<TextFormField>(fields.at(2)).enabled, isTrue);
        expect(find.byType(PasswordInput), findsNothing);
        for (final index in [1]) {
          expect(t.widget<TextFormField>(fields.at(index)).enabled, isFalse);
        }
        expect(
          t.widget<TextFormField>(fields.at(1)).controller!.text,
          'guardian@independent.example',
        );
        await edit(t, fields.at(0), 'Corrected Guardian');
        await edit(t, fields.at(2), '0509876543');
        repo.pending = null;
        repo.reject = true;
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(repo.attempts.last, ('Corrected Guardian', '0509876543'));
        expect(auth.attempts, hasLength(1));
        expect(auth.registrations, 1);
        expect(t.widget<TextFormField>(fields.at(1)).enabled, isFalse);
        repo.reject = false;
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(find.text('Session destination'), findsOneWidget);
        expect(auth.attempts, hasLength(1));
        expect(repo.attempts, hasLength(3));
        expect(repo.person.fullName, 'Corrected Guardian');
      },
    );

    testWidgets(
      'Signup persists only non-credential hints and retains passwords only in memory in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(3));
        expect(find.byType(PasswordInput), findsNothing);
        expect(
          t.widget<TextFormField>(fields.first).controller!.text,
          'Test Guardian',
        );
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys()) {
          final value = prefs.get(key).toString();
          expect(value, isNot(contains('ValidPass1!')));
          expect(value, isNot(contains('emailVerified')));
        }
        final draft = await RegistrationDraft.read(auth.uid);
        expect(draft['name'], 'Test Guardian');
        expect(draft['phone'], '0501234567');
        await pressText(t, s.registrationEditInformation);
        expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).at(3))
              .controller!
              .text,
          'ValidPass1!',
        );
        expect(
          t
              .widget<TextFormField>(find.byType(TextFormField).at(4))
              .controller!
              .text,
          'ValidPass1!',
        );
        expect(repo.attempts, isEmpty);
        expect(auth.registrations, 1);
      },
    );

    testWidgets(
      'Edit failure stays in the popup until its safe retry in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        auth.rejectLogout = true;
        await pressText(t, s.registrationEditInformation);
        expect(find.text(s.networkError), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expectEnabled(t, false);
        auth.rejectLogout = false;
        await pressText(t, s.registrationEditInformation);
        expect(auth.signedIn, isFalse);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(TextFormField), findsNWidgets(5));
        expectEnabled(t, true);
        expect(repo.attempts, isEmpty);
      },
    );

    testWidgets(
      'Resend cooldown does not unlock unverified Guardian access in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        final cooldown = find.widgetWithText(
          TextButton,
          '${s.registrationResendLink} (${s.verificationCooldown(60)})',
        );
        expect(t.widget<TextButton>(cooldown).onPressed, isNull);
        expect(auth.verificationRequests, [language]);
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        await t.pumpAndSettle();
        expect(find.text(s.emailNotVerified), findsNothing);
        expect(repo.attempts, isEmpty);
        expect(auth.registrations, 1);
      },
    );

    testWidgets(
      'Edit deletes the unverified registration and retains all form values in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        await pressText(t, s.registrationEditInformation);
        expect(find.byType(AlertDialog), findsNothing);
        expect(auth.signedIn, isFalse);
        expectEnabled(t, true);
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(5));
        expect(
          t.widget<TextFormField>(fields.at(0)).controller!.text,
          'Test Guardian',
        );
        expect(
          t.widget<TextFormField>(fields.at(1)).controller!.text,
          'guardian@independent.example',
        );
        expect(
          t.widget<TextFormField>(fields.at(2)).controller!.text,
          '0501234567',
        );
        expect(
          t.widget<TextFormField>(fields.at(3)).controller!.text,
          'ValidPass1!',
        );
        expect(
          t.widget<TextFormField>(fields.at(4)).controller!.text,
          'ValidPass1!',
        );
        expect(
          t.widget<CheckboxListTile>(find.byType(CheckboxListTile).first).value,
          isTrue,
        );
        await edit(t, fields.first, 'Corrected Guardian');
        await edit(t, fields.at(2), 'bad');
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(find.text(s.invalidPhone), findsOneWidget);
        expect(auth.registrations, 1);
        await edit(t, fields.at(2), '0509876543');
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(auth.registrations, 2);
        expect(auth.emailCorrections, isEmpty);
        auth.emailVerified = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(repo.attempts.single, ('Corrected Guardian', '0509876543'));
      },
    );

    testWidgets(
      'Edited email creates a fresh registration and displays the exact trimmed input in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        await pressText(t, s.registrationEditInformation);
        await edit(
          t,
          find.byType(TextFormField).at(1),
          '  Corrected@independent.example  ',
        );
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(
          find.text('${s.registrationLinkSent} Corrected@independent.example'),
          findsOneWidget,
        );
        expect(auth.email, 'Corrected@independent.example');
        expect(auth.registrations, 2);
        expect(auth.emailCorrections, isEmpty);
        expect(
          find.byKey(const ValueKey('registration-reauthentication')),
          findsNothing,
        );
        expect(repo.attempts, isEmpty);
      },
    );

    testWidgets(
      'Edited registration starts a new popup-owned cooldown in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 1));
        expect(
          find.text(
            '${s.registrationResendLink} (${s.verificationCooldown(59)})',
          ),
          findsOneWidget,
        );
        await pressText(t, s.registrationEditInformation);
        await edit(
          t,
          find.byType(TextFormField).at(1),
          'corrected@example.test',
        );
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(
          find.text(
            '${s.registrationResendLink} (${s.verificationCooldown(60)})',
          ),
          findsOneWidget,
        );
        expect(auth.verificationRequests, [language, language]);
        expect(auth.emailCorrections, isEmpty);
      },
    );

    for (final (code, message) in [
      ('credentials', s.invalidCredentials),
      ('emailExists', s.emailExists),
      ('network', s.networkError),
      ('rateLimit', s.rateLimit),
    ]) {
      testWidgets(
        'Edited registration failure $code preserves the form without a popup in $language',
        (t) async {
          await mount(t, const AuthScreen(mode: AuthMode.register), language);
          await fillRegistration(t);
          await submit(t, s.createAccount);
          await t.pumpAndSettle();
          await pressText(t, s.registrationEditInformation);
          await edit(
            t,
            find.byType(TextFormField).at(1),
            'corrected@example.test',
          );
          auth.registrationFailure = code;
          await submit(t, s.createAccount);
          await t.pumpAndSettle();
          expect(find.text(message), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expectEnabled(t, true);
          expect(auth.registrations, 1);
          expect(auth.emailCorrections, isEmpty);
          expect(repo.attempts, isEmpty);
          expect(
            t
                .widget<TextFormField>(find.byType(TextFormField).at(1))
                .controller!
                .text,
            'corrected@example.test',
          );
        },
      );
    }

    testWidgets(
      'Edited-email resend uses the current Auth email without credentials in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        await pressText(t, s.registrationEditInformation);
        await edit(
          t,
          find.byType(TextFormField).at(1),
          'corrected@example.test',
        );
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 60));
        await t.pumpAndSettle();
        final resend = find.widgetWithText(
          TextButton,
          s.registrationResendLink,
        );
        expect(t.widget<TextButton>(resend).onPressed, isNotNull);
        await t.tap(resend);
        await t.pumpAndSettle();
        expect(auth.verificationRequests, [language, language, language]);
        expect(auth.emailCorrections, isEmpty);
        expect(auth.registrations, 2);
        expect(
          find.text('${s.registrationLinkSent} corrected@example.test'),
          findsOneWidget,
        );
        expect(
          find.text(
            '${s.registrationResendLink} (${s.verificationCooldown(60)})',
          ),
          findsOneWidget,
        );
        expect(repo.attempts, isEmpty);
      },
    );

    if (language == 'en') {
      testWidgets(
        'Rejected resend shows one error and allows another attempt in $language',
        (t) async {
          await mount(t, const AuthScreen(mode: AuthMode.register), language);
          await fillRegistration(t);
          await submit(t, s.createAccount);
          await t.pumpAndSettle();
          await t.pump(const Duration(seconds: 60));
          await t.pumpAndSettle();
          auth.sendFailure = 'rateLimit';
          await pressText(t, s.registrationResendLink);
          expect(find.text(s.rateLimit), findsOneWidget);
          expect(auth.registrations, 1);
          expect(auth.verificationRequests, [language, language]);
          expect(auth.emailCorrections, isEmpty);
          expect(repo.attempts, isEmpty);
          expect(
            t
                .widget<TextButton>(
                  find.widgetWithText(TextButton, s.registrationResendLink),
                )
                .onPressed,
            isNotNull,
          );
        },
      );
    }

    testWidgets(
      'Edited passwords keep confirmation validation and are never persisted in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        await pressText(t, s.registrationEditInformation);
        final fields = find.byType(TextFormField);
        await edit(t, fields.at(3), 'NewValidPass2!');
        await edit(t, fields.at(4), 'WrongValidPass2!');
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(find.text(s.passwordMismatch), findsOneWidget);
        expect(auth.registrations, 1);
        await edit(t, fields.at(4), 'NewValidPass2!');
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(auth.registrations, 2);
        expect(auth.attempts.last.$2, 'NewValidPass2!');
        expect(auth.passwordUpdates, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys()) {
          expect(prefs.get(key).toString(), isNot(contains('NewValidPass2!')));
        }
      },
    );

    testWidgets(
      'Edit never deletes an account that has become verified in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        auth.emailVerified = true;
        await pressText(t, s.registrationEditInformation);
        expect(auth.signedIn, isTrue);
        expect(auth.registrations, 1);
        expect(auth.passwordUpdates, isEmpty);
        expect(find.text('Session destination'), findsOneWidget);
        expect(repo.attempts.single, ('Test Guardian', '0501234567'));
      },
    );

    testWidgets(
      'Combined email and password edits retry a failed send without another creation in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        await pressText(t, s.registrationEditInformation);
        await edit(
          t,
          find.byType(TextFormField).at(1),
          'combined@example.test',
        );
        await edit(t, find.byType(TextFormField).at(3), 'NewValidPass2!');
        await edit(t, find.byType(TextFormField).at(4), 'NewValidPass2!');
        auth.sendFailure = 'network';
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(find.text(s.networkError), findsOneWidget);
        expect(auth.registrations, 2);
        auth.sendFailure = null;
        await pressText(t, s.registrationResendLink);
        expect(auth.registrations, 2);
        expect(auth.emailCorrections, isEmpty);
        expect(auth.passwordUpdates, isEmpty);
        auth.emailVerified = true;
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(repo.attempts, hasLength(1));
        expect(find.text('Session destination'), findsOneWidget);
      },
    );

    testWidgets(
      'Existing signed-in identity is recovered without creating or modifying another account in $language',
      (t) async {
        auth.active = true;
        final uid = auth.uid, email = auth.email;
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(auth.uid, uid);
        expect(auth.email, email);
        expect(auth.registrations, 0);
        expect(auth.verificationRequests, isEmpty);
        expect(repo.attempts, isEmpty);
        expect(find.text('Session destination'), findsOneWidget);
      },
    );

    testWidgets(
      'Duplicate Create Account taps issue one SDK creation in $language',
      (t) async {
        auth.pending = Completer<void>();
        auth.sendPending = Completer<void>();
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        final button = find.widgetWithText(FilledButton, s.createAccount);
        final callback = t.widget<FilledButton>(button).onPressed!;
        callback();
        callback();
        await t.pump();
        expect(auth.attempts, hasLength(1));
        expectEnabled(t, false);
        expect(repo.attempts, isEmpty);
        auth.pending!.complete();
        for (var i = 0; i < 10 && auth.verificationRequests.isEmpty; i++) {
          await t.pump(const Duration(milliseconds: 10));
        }
        expect(auth.verificationRequests, [language]);
        expect(find.byType(AlertDialog), findsNothing);
        auth.sendPending!.complete();
        await t.pumpAndSettle();
        expect(auth.registrations, 1);
        expect(auth.verificationRequests, [language]);
        expect(repo.attempts, isEmpty);
      },
    );

    testWidgets(
      'A definite collision never adopts a concurrently signed-in account in $language',
      (t) async {
        auth.registrationFailure = 'emailExists';
        auth.collisionSession = true;
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(find.text(s.emailExists), findsOneWidget);
        expect(auth.uid, 'existing-account');
        expect(auth.registrations, 0);
        expect(auth.verificationRequests, isEmpty);
        expect(repo.attempts, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'Existing-email collision preserves identity without redundant signup links in $language',
      (t) async {
        auth.registrationFailure = 'emailExists';
        final uid = auth.uid, email = auth.email;
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        await fillRegistration(t);
        await submit(t, s.createAccount);
        await t.pumpAndSettle();
        expect(find.text(s.emailExists), findsOneWidget);
        expect(find.text(s.alreadyAccount), findsNothing);
        expect(find.widgetWithText(TextButton, s.login), findsNothing);
        expect(find.widgetWithText(TextButton, s.forgotPassword), findsNothing);
        expect(auth.uid, uid);
        expect(auth.email, email);
        expect(auth.signedIn, isFalse);
        expect(auth.registrations, 0);
        expect(auth.verificationRequests, isEmpty);
        expect(repo.attempts, isEmpty);
        expectEnabled(t, true);
      },
    );
  }
}
