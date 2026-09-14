import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/app/radd_app.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/auth/presentation/auth_screen.dart';
import 'package:radd/features/auth/presentation/session_screen.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/guardian_home_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:radd/features/onboarding/presentation/screens/role_selection_screen.dart';

import 'support/guardian_fakes.dart';

class SessionRepository extends TestRepository {
  String role = 'guardian';
  String? failure;
  int roleReads = 0, profileReads = 0;
  Completer<String>? pendingRole;
  @override
  Future<String> accountRole() async {
    roleReads++;
    if (pendingRole != null) return pendingRole!.future;
    if (failure != null) throw AppFailure(failure!);
    return role;
  }

  @override
  Future<GuardianProfile> createProfile(String name, String phone) async {
    failure = null;
    return super.createProfile(name, phone);
  }

  @override
  Future<GuardianProfile> profile() async {
    profileReads++;
    return super.profile();
  }
}

void main() {
  late TestAuth auth;
  late SessionRepository repo;
  setUp(() {
    auth = TestAuth();
    repo = SessionRepository();
  });
  tearDown(() async {
    await auth.events.close();
  });
  Future<void> launch(WidgetTester t, {String language = 'en'}) async {
    await t.pumpWidget(
      AppServices(
        auth: auth,
        guardian: repo,
        child: RaddApp(locale: Locale(language)),
      ),
    );
    await t.pump(const Duration(milliseconds: 3800));
    await t.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Signed-out cold start preserves $language but never assumes role',
      (t) async {
        await launch(t, language: language);
        expect(find.byType(LanguageSelectionScreen), findsOneWidget);
        expect(repo.roleReads, 0);
        expect(repo.profileReads, 0);
        final context = t.element(find.byType(LanguageSelectionScreen));
        Navigator.of(context).pushNamed(AppRoutes.roleSelection);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('guardian-role')));
        await t.pumpAndSettle();
        expect(
          t.widget<AuthScreen>(find.byType(AuthScreen)).volunteer,
          isFalse,
        );
        expect(repo.profileReads, 0);
      },
    );
  }
  testWidgets('Valid Guardian cold start resolves role before Home', (t) async {
    auth.active = true;
    await launch(t);
    expect(repo.roleReads, 1);
    expect(repo.profileReads, greaterThan(0));
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
    expect(find.byType(LanguageSelectionScreen), findsNothing);
  });
  testWidgets('Volunteer session never loads Guardian and signup is absent', (
    t,
  ) async {
    auth.active = true;
    repo.role = 'volunteer';
    await launch(t);
    expect(repo.profileReads, 0);
    expect(find.byType(GuardianHomeScreen), findsNothing);
    await t.tap(find.text('Return to Role Selection'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('volunteer-role')));
    await t.pumpAndSettle();
    expect(t.widget<AuthScreen>(find.byType(AuthScreen)).volunteer, isTrue);
    expect(find.text('Create Account'), findsNothing);
  });
  testWidgets(
    'Unavailable backend provides recovery without requiring logout',
    (t) async {
      auth.active = true;
      repo.failure = 'service';
      await launch(t);
      expect(find.text('Account recovery'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(repo.profileReads, 0);
      await t.tap(find.text('Return to Role Selection'));
      await t.pumpAndSettle();
      expect(auth.active, isTrue);
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(find.byType(GuardianHomeScreen), findsNothing);
    },
  );
  testWidgets(
    'Missing profile can be completed without another Auth registration',
    (t) async {
      auth.active = true;
      repo.failure = 'notFound';
      await launch(t);
      await t.tap(find.text('Complete Guardian profile'));
      await t.pumpAndSettle();
      expect(
        t.widget<AuthScreen>(find.byType(AuthScreen)).mode,
        AuthMode.completeProfile,
      );
      expect(auth.registrations, 0);
      expect(find.byType(TextFormField), findsNWidgets(2));
      await t.enterText(find.byType(TextFormField).first, 'Recovered Guardian');
      await t.enterText(find.byType(TextFormField).last, '+966500000001');
      for (final field in find.byType(CheckboxListTile).evaluate().toList()) {
        final finder = find.byWidget(field.widget);
        await t.ensureVisible(finder);
        await t.tap(finder);
        await t.pumpAndSettle();
      }
      await t.ensureVisible(find.text('Save'));
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.byType(GuardianHomeScreen), findsOneWidget);
      expect(auth.registrations, 0);
      expect(repo.person.fullName, 'Recovered Guardian');
    },
  );
  testWidgets('Retry resolves role and profile after service recovery', (
    t,
  ) async {
    auth.active = true;
    repo.failure = 'service';
    await launch(t);
    repo.failure = null;
    await t.tap(find.text('Try Again'));
    await t.pumpAndSettle();
    expect(find.byType(GuardianHomeScreen), findsOneWidget);
  });
  testWidgets('Signout during resolution cannot let a stale result open Home', (
    t,
  ) async {
    auth.active = true;
    repo.pendingRole = Completer<String>();
    await t.pumpWidget(
      AppServices(auth: auth, guardian: repo, child: const RaddApp()),
    );
    await t.pump(const Duration(milliseconds: 3800));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(SessionScreen), findsOneWidget);
    await auth.logout();
    await t.pumpAndSettle();
    repo.pendingRole!.complete('guardian');
    await t.pumpAndSettle();
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(find.byType(GuardianHomeScreen), findsNothing);
    expect(repo.profileReads, 0);
    expect(t.takeException(), isNull);
  });
}
