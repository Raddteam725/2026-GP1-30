import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/app/app_services.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/core/routing/app_routes.dart';
import 'package:radd/features/auth/presentation/auth_screen.dart';
import 'package:radd/features/guardian/data/guardian_repository.dart';
import 'package:radd/features/guardian/presentation/edit_guardian_profile_screen.dart';
import 'package:radd/features/guardian/presentation/individual_form_screen.dart';

import 'support/guardian_fakes.dart';
import 'volunteer_navigation_test.dart' show harness;

void main() {
  late TestAuth auth;
  late TestRepository repo;

  setUp(() {
    auth = TestAuth();
    repo = TestRepository();
  });
  tearDown(() => auth.events.close());

  Future<void> mount(WidgetTester t, Widget screen, String language) async {
    t.view.physicalSize = const Size(800, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      AppServices(auth: auth, guardian: repo, child: harness(screen, language)),
    );
    await t.pumpAndSettle();
  }

  String? error(WidgetTester t, Finder field) =>
      t.state<FormFieldState<String>>(field).errorText;

  Future<void> edit(WidgetTester t, Finder field, String value) async {
    await t.ensureVisible(field);
    await t.enterText(field, value);
    await t.pumpAndSettle();
  }

  Future<void> exercise(
    WidgetTester t,
    Finder field, {
    required String invalid,
    required String valid,
    required String invalidMessage,
    required String requiredMessage,
  }) async {
    expect(error(t, field), isNull);
    await edit(t, field, invalid);
    expect(error(t, field), invalidMessage);
    await edit(t, field, valid);
    expect(error(t, field), isNull);
    await edit(t, field, '');
    expect(error(t, field), requiredMessage);
    await edit(t, field, valid);
    expect(error(t, field), isNull);
  }

  for (final language in ['en', 'ar']) {
    final s = lookupAppLocalizations(Locale(language));

    testWidgets(
      'Register live validation and password dependencies in $language',
      (t) async {
        await mount(t, const AuthScreen(mode: AuthMode.register), language);
        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(5));
        for (var i = 0; i < 5; i++) {
          expect(error(t, fields.at(i)), isNull);
        }
        await exercise(
          t,
          fields.at(0),
          invalid: 'x' * 121,
          valid: 'Test Guardian',
          invalidMessage: s.invalidName,
          requiredMessage: s.requiredField,
        );
        // Editing one field must never expose errors on its pristine neighbors.
        expect(error(t, fields.at(1)), isNull);
        await exercise(
          t,
          fields.at(1),
          invalid: 'bad@',
          valid: 'test@example.test',
          invalidMessage: s.invalidEmail,
          requiredMessage: s.requiredField,
        );
        await exercise(
          t,
          fields.at(2),
          invalid: '0412345678',
          valid: '٠٥٠١٢٣٤٥٦٧',
          invalidMessage: s.invalidPhone,
          requiredMessage: s.requiredField,
        );
        await exercise(
          t,
          fields.at(3),
          invalid: 'weak',
          valid: 'ValidPass1!',
          invalidMessage: s.passwordHelp,
          requiredMessage: s.requiredField,
        );
        expect(error(t, fields.at(4)), isNull);
        await exercise(
          t,
          fields.at(4),
          invalid: 'Different1!',
          valid: 'ValidPass1!',
          invalidMessage: s.passwordMismatch,
          requiredMessage: s.requiredField,
        );
        await edit(t, fields.at(3), 'ValidPass2!');
        expect(error(t, fields.at(4)), s.passwordMismatch);
        await edit(t, fields.at(3), 'ValidPass1!');
        expect(error(t, fields.at(4)), isNull);

        final checkboxes = find.byType(CheckboxListTile);
        final checkboxFields = find.ancestor(
          of: checkboxes,
          matching: find.byType(FormField<bool>),
        );
        for (var i = 0; i < 2; i++) {
          expect(
            t.state<FormFieldState<bool>>(checkboxFields.at(i)).errorText,
            isNull,
          );
          await t.ensureVisible(checkboxes.at(i));
          await t.tap(checkboxes.at(i));
          await t.pumpAndSettle();
          await t.tap(checkboxes.at(i));
          await t.pumpAndSettle();
          expect(
            t.state<FormFieldState<bool>>(checkboxFields.at(i)).errorText,
            s.requiredField,
          );
          await t.tap(checkboxes.at(i));
          await t.pumpAndSettle();
          expect(
            t.state<FormFieldState<bool>>(checkboxFields.at(i)).errorText,
            isNull,
          );
        }
        expect(auth.registrations, 0);
      },
    );

    for (final volunteer in [false, true]) {
      testWidgets(
        'Login live format and required-only password $volunteer in $language',
        (t) async {
          await mount(t, AuthScreen(volunteer: volunteer), language);
          final fields = find.byType(TextFormField);
          await exercise(
            t,
            fields.first,
            invalid: 'bad',
            valid: 'login@example.test',
            invalidMessage: s.invalidEmail,
            requiredMessage: s.requiredField,
          );
          await edit(t, fields.last, 'legacy');
          expect(error(t, fields.last), isNull); // Do not apply sign-up policy.
          await edit(t, fields.last, '');
          expect(error(t, fields.last), s.requiredField);
          await edit(t, fields.last, 'legacy');
          expect(error(t, fields.last), isNull);
          expect(auth.logins, 0); // No server auth on each keystroke.
        },
      );
    }

    testWidgets('Reset email live format validation in $language', (t) async {
      await mount(t, const AuthScreen(mode: AuthMode.reset), language);
      await exercise(
        t,
        find.byType(TextFormField),
        invalid: 'bad',
        valid: 'reset@example.test',
        invalidMessage: s.invalidEmail,
        requiredMessage: s.requiredField,
      );
      expect(auth.resetRequests, isEmpty);
    });

    testWidgets('Complete profile live validation in $language', (t) async {
      await mount(
        t,
        const AuthScreen(mode: AuthMode.completeProfile),
        language,
      );
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await exercise(
        t,
        fields.first,
        invalid: 'x' * 121,
        valid: 'Guardian',
        invalidMessage: s.invalidName,
        requiredMessage: s.requiredField,
      );
      await exercise(
        t,
        fields.last,
        invalid: 'bad',
        valid: '0501234567',
        invalidMessage: s.invalidPhone,
        requiredMessage: s.requiredField,
      );
      final form = t.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse); // Both declarations remain required.
      await t.pumpAndSettle();
      expect(find.text(s.requiredField), findsNWidgets(2));
    });

    testWidgets(
      'Edit Guardian profile validates changed existing values in $language',
      (t) async {
        await mount(
          t,
          EditGuardianProfileScreen(profile: repo.person),
          language,
        );
        final fields = find.byType(TextFormField);
        await exercise(
          t,
          fields.first,
          invalid: 'x' * 121,
          valid: 'Updated Guardian',
          invalidMessage: s.invalidName,
          requiredMessage: s.requiredField,
        );
        await exercise(
          t,
          fields.last,
          invalid: 'bad',
          valid: '0501234567',
          invalidMessage: s.invalidPhone,
          requiredMessage: s.requiredField,
        );
        expect(find.text(repo.person.email), findsOneWidget); // Read-only.
      },
    );

    testWidgets(
      'Individual required selections and conditional relationship in $language',
      (t) async {
        await mount(t, const IndividualFormScreen(), language);
        final age = find.byKey(const ValueKey('individual-age'));
        await exercise(
          t,
          find.byType(TextFormField).first,
          invalid: 'x' * 121,
          valid: 'Test Person',
          invalidMessage: s.invalidName,
          requiredMessage: s.requiredField,
        );
        expect(find.text(s.photoRequired), findsNothing);
        expect(
          t.state<FormFieldState<String>>(
            find.byKey(const ValueKey('individual-gender')),
          ).errorText,
          isNull,
        );
        final ageWidget = t.widget<FormField<int>>(age);
        expect(ageWidget.initialValue, isNull);
        expect(
          find.descendant(
            of: age,
            matching: find.text(language == 'ar' ? 'اختر العمر' : 'Select age'),
          ),
          findsOneWidget,
        );
        expect(ageWidget.autovalidateMode, AutovalidateMode.onUserInteraction);
        expect(t.state<FormFieldState<int>>(age).errorText, isNull);
        final form = t.state<FormState>(find.byType(Form));
        expect(form.validate(), isFalse);
        await t.pumpAndSettle();
        expect(t.state<FormFieldState<int>>(age).errorText, s.invalidAge);
        await t.tap(age);
        await t.pumpAndSettle();
        final ageMenu = find.byKey(const ValueKey('individual-age-menu'));
        expect(t.getTopLeft(ageMenu).dy, greaterThanOrEqualTo(t.getBottomLeft(age).dy));
        expect(t.getSize(ageMenu).width, t.getSize(age).width);
        expect(
          t.widget<ListView>(find.descendant(of: ageMenu, matching: find.byType(ListView)))
              .childrenDelegate.estimatedChildCount,
          131,
        );
        await t.tap(find.text('0').last);
        await t.pumpAndSettle();
        expect(t.state<FormFieldState<int>>(age).value, 0);
        expect(t.state<FormFieldState<int>>(age).errorText, isNull);

        await edit(t, find.byType(TextFormField).first, 'Test Person');
        await t.tap(find.text(s.female));
        await t.pumpAndSettle();
        final relationship = find.byKey(const ValueKey('individual-relationship'));
        await t.tap(relationship);
        await t.pumpAndSettle();
        final relationshipMenu = find.byKey(const ValueKey('individual-relationship-menu'));
        expect(t.getTopLeft(relationshipMenu).dy,
          greaterThanOrEqualTo(t.getBottomLeft(relationship).dy));
        expect(t.getSize(relationshipMenu).width, t.getSize(relationship).width);
        expect(t.getSize(relationshipMenu).height, 3 * 48);
        expect(find.text(s.child), findsOneWidget);
        expect(find.text(s.parent), findsOneWidget);
        await t.tap(find.text(s.other).last);
        await t.pumpAndSettle();
        final other = find.byType(TextFormField).last;
        expect(error(t, other), isNull); // Newly visible field is pristine.
        await edit(t, other, ' ');
        expect(error(t, other), s.requiredField);
        await edit(t, other, 'Family friend');
        expect(error(t, other), isNull);
        await edit(t, other, '');
        expect(error(t, other), s.requiredField);
        await t.tap(relationship);
        await t.pumpAndSettle();
        await t.tap(find.text(s.child).last);
        await t.pumpAndSettle();
        expect(find.byType(TextFormField), findsOneWidget);
        expect(form.validate(), isTrue); // Hidden Other cannot block submit.
        await t.pumpAndSettle();
        expect(repo.records, isEmpty);
      },
    );

    testWidgets('Individual dropdown dismissal and text blur validate only touched fields in $language', (t) async {
      await mount(t, const IndividualFormScreen(), language);
      final name = find.byType(TextFormField).first;
      final age = find.byKey(const ValueKey('individual-age'));
      final relationship = find.byKey(const ValueKey('individual-relationship'));
      final nameFocus = t.widget<EditableText>(find.descendant(
        of: name, matching: find.byType(EditableText))).focusNode;
      await t.tap(name);
      await t.pumpAndSettle();
      expect(nameFocus.hasFocus, isTrue);
      await t.tap(age);
      await t.pumpAndSettle();
      expect(nameFocus.hasFocus, isFalse);
      expect(error(t, name), s.requiredField);
      expect(t.state<FormFieldState<int>>(age).errorText, isNull);
      expect(find.text(s.invalidAge), findsNothing);
      expect(t.testTextInput.isVisible, isFalse);
      await t.tapAt(const Offset(5, 200));
      await t.pumpAndSettle();
      expect(t.state<FormFieldState<int>>(age).errorText, s.invalidAge);
      await t.tap(age);
      await t.pumpAndSettle();
      expect(find.descendant(of: age, matching: find.text(s.invalidAge)), findsNothing);
      await t.tap(find.text('0').last);
      await t.pumpAndSettle();
      expect(t.state<FormFieldState<int>>(age).errorText, isNull);
      await t.tap(relationship);
      await t.pumpAndSettle();
      expect(t.state<FormFieldState<String>>(relationship).errorText, isNull);
      expect(t.getSize(find.byKey(const ValueKey('individual-relationship-menu'))).height, 144);
      await t.tapAt(const Offset(5, 200));
      await t.pumpAndSettle();
      expect(t.state<FormFieldState<String>>(relationship).errorText, s.requiredField);
      await t.tap(relationship);
      await t.pumpAndSettle();
      expect(find.descendant(of: relationship, matching: find.text(s.requiredField)), findsNothing);
      await t.tap(find.text(s.other).last);
      await t.pumpAndSettle();
      expect(t.state<FormFieldState<String>>(relationship).errorText, isNull);
      final other = find.byType(TextFormField).last;
      expect(error(t, other), isNull);
      await t.tap(other);
      await t.pumpAndSettle();
      final otherFocus = t.widget<EditableText>(find.descendant(
        of: other, matching: find.byType(EditableText))).focusNode;
      expect(otherFocus.hasFocus, isTrue);
      await t.tap(find.text(s.female));
      await t.pumpAndSettle();
      expect(otherFocus.hasFocus, isFalse);
      expect(error(t, other), s.requiredField);
      await edit(t, other, 'Family friend');
      expect(error(t, other), isNull);
      await t.tap(name);
      await t.pumpAndSettle();
      expect(otherFocus.hasFocus, isFalse);
      await edit(t, name, 'Updated Person');
      expect(error(t, name), isNull);
      await t.tapAt(const Offset(5, 200));
      await t.pumpAndSettle();
      expect(nameFocus.hasFocus, isFalse);
      expect(find.text(s.photoRequired), findsNothing);
      expect(repo.records, isEmpty);
    });

    testWidgets('Individual Save scrolls to the first error and corrections clear live in $language', (t) async {
      final person = Individual(
        id: 'invalid-individual',
        fullName: 'Person',
        age: 7,
        gender: '',
        relationship: '',
      );
      repo.records.add(person);
      await mount(t, IndividualFormScreen(individual: person), language);
      final name = find.byType(TextFormField).first;
      final gender = find.byKey(const ValueKey('individual-gender'));
      final relationship = find.byKey(const ValueKey('individual-relationship'));
      expect(error(t, name), isNull);
      expect(t.state<FormFieldState<String>>(gender).errorText, isNull);
      expect(t.state<FormFieldState<String>>(relationship).errorText, isNull);
      await edit(t, name, '');
      expect(error(t, name), s.requiredField);
      await t.ensureVisible(find.text(s.saveChanges));
      await t.tap(find.text(s.saveChanges));
      await t.pumpAndSettle();
      expect(t.getTopLeft(name).dy, greaterThanOrEqualTo(0));
      expect(t.getBottomLeft(name).dy, lessThan(t.view.physicalSize.height));
      expect(t.state<FormFieldState<String>>(gender).errorText, s.requiredField);
      expect(t.state<FormFieldState<String>>(relationship).errorText, s.requiredField);
      await edit(t, name, 'Updated Person');
      expect(error(t, name), isNull);
      await t.ensureVisible(gender);
      await t.tap(find.text(s.female));
      await t.pumpAndSettle();
      expect(t.state<FormFieldState<String>>(gender).errorText, isNull);
      await t.ensureVisible(relationship);
      await t.tap(relationship);
      await t.pumpAndSettle();
      await t.tap(find.text(s.child).last);
      await t.pumpAndSettle();
      expect(t.state<FormFieldState<String>>(relationship).errorText, isNull);
      expect(repo.records.single.fullName, 'Person');
    });
  }

  for (final ageValue in [0, 7, 130]) {
    testWidgets(
      'Edit preserves integer age $ageValue and saves dropdown selection',
      (t) async {
        final person = Individual(
          id: 'person',
          fullName: 'Person',
          age: ageValue,
          gender: 'female',
          relationship: 'child',
        );
        repo.records.add(person);
        await mount(t, IndividualFormScreen(individual: person), 'en');
        final age = find.byKey(const ValueKey('individual-age'));
        expect(t.state<FormFieldState<int>>(age).value, ageValue);
        expect(t.state<FormFieldState<int>>(age).errorText, isNull);
        await t.tap(age);
        await t.pumpAndSettle();
        final target = find.text(ageValue == 130 ? '0' : '130');
        await t.scrollUntilVisible(
          target,
          ageValue == 130 ? -500 : 500,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('individual-age-menu')),
            matching: find.byType(Scrollable),
          ),
          maxScrolls: 40,
        );
        await t.pumpAndSettle();
        await t.tap(target.last);
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Save Changes'));
        await t.tap(find.text('Save Changes'));
        await t.pumpAndSettle();
        expect(repo.records.single.age, ageValue == 130 ? 0 : 130);
      },
    );
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      'Age menu stays compact and scrolls to both integer boundaries in $language',
      (t) async {
        final person = Individual(
          id: 'compact-age',
          fullName: 'Person',
          age: 7,
          gender: 'female',
          relationship: 'child',
        );
        repo.records.add(person);
        await mount(t, IndividualFormScreen(individual: person), language);
        t.view.physicalSize = const Size(400, 800);
        await t.pumpAndSettle();
        final age = find.byKey(const ValueKey('individual-age'));
        await t.ensureVisible(age);
        await t.pumpAndSettle();
        final page = t.state<ScrollableState>(find.ancestor(
          of: age, matching: find.byType(Scrollable)).first);
        final offset = page.position.pixels;
        await t.tap(age);
        await t.pumpAndSettle();
        expect(page.position.pixels, offset);
        expect(t.testTextInput.isVisible, isFalse);
        expect(find.descendant(of: age, matching: find.byType(TextField)), findsNothing);
        final scroll = find.descendant(
          of: find.byKey(const ValueKey('individual-age-menu')),
          matching: find.byType(Scrollable),
        );
        final menu = find.byKey(const ValueKey('individual-age-menu'));
        expect(
          t.getTopLeft(menu).dy >= t.getBottomLeft(age).dy ||
              t.getBottomLeft(menu).dy <= t.getTopLeft(age).dy,
          isTrue,
        );
        expect(t.getSize(menu).width, t.getSize(age).width);
        expect(t.getSize(scroll).height, lessThanOrEqualTo(280));
        expect(
          Directionality.of(t.element(scroll)),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        await t.scrollUntilVisible(
          find.text('130'),
          200,
          scrollable: scroll,
          maxScrolls: 40,
        );
        await t.pumpAndSettle();
        await t.tap(find.text('130').last);
        await t.pumpAndSettle();
        expect(t.state<FormFieldState<int>>(age).value, 130);
        expect(t.state<FormFieldState<int>>(age).errorText, isNull);
        await t.tap(age);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('0'),
          -200,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('individual-age-menu')),
            matching: find.byType(Scrollable),
          ),
          maxScrolls: 40,
        );
        await t.pumpAndSettle();
        await t.tap(find.text('0').last);
        await t.pumpAndSettle();
        expect(t.state<FormFieldState<int>>(age).value, 0);
        expect(t.state<FormFieldState<int>>(age).errorText, isNull);
        await Scrollable.ensureVisible(t.element(age), alignment: 1);
        await t.pumpAndSettle();
        final bottomOffset = page.position.pixels;
        await t.tap(age);
        await t.pumpAndSettle();
        expect(page.position.pixels, bottomOffset);
        expect(t.getBottomLeft(menu).dy, lessThanOrEqualTo(t.getTopLeft(age).dy));
        expect(t.testTextInput.isVisible, isFalse);
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Photo capture preserves original cancellation and clears submission errors',
    (t) async {
      Uint8List? result;
      await mount(
        t,
        Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<Object?>(
            builder: (context) => settings.name == AppRoutes.camera
                ? Scaffold(
                    body: FilledButton(
                      onPressed: () => Navigator.pop(context, result),
                      child: const Text('Return capture'),
                    ),
                  )
                : const IndividualFormScreen(),
          ),
        ),
        'en',
      );
      expect(find.text('Photo required.'), findsNothing);
      await t.tap(find.text('Take Photo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Return capture'));
      await t.pumpAndSettle();
      expect(find.text('Photo required.'), findsNothing);
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('Photo required.'), findsOneWidget);
      result = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGP8//8/AwwwwVl4OQCWbgMF7ZjH1AAAAABJRU5ErkJggg==',
      );
      await t.tap(find.text('Take Photo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Return capture'));
      await t.pumpAndSettle();
      expect(find.text('Photo required.'), findsNothing);
      expect(find.text('Retake Photo'), findsOneWidget);
    },
  );
}
