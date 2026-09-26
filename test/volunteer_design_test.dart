import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/data/mock_volunteer_repository.dart';
import 'package:radd/features/volunteer/presentation/volunteer_workspace.dart';

import 'volunteer_navigation_test.dart' show harness;

class DesignRepository extends MockVolunteerRepository {
  @override
  bool get isPreview => false;
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('Shared Volunteer profile and logout design in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = Platform.environment['RADD_CAPTURE_UI'] == '1';
      if (capture) {
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        for (final font in ['Inter', 'Tajawal']) {
          final loader = FontLoader(font)
            ..addFont(
              rootBundle.load(
                font == 'Inter'
                    ? 'assets/fonts/inter/Inter.ttf'
                    : 'assets/fonts/tajawal/Tajawal-Regular.ttf',
              ),
            );
          await loader.load();
        }
      }
      final repo = DesignRepository();
      addTearDown(repo.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: harness(
            VolunteerWorkspace(
              account: MockVolunteerRepository.account,
              repository: repo,
              onLogout: () async {},
            ),
            language,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> screenshot(String name) async {
        if (!capture) return;
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/radd-volunteer-$language-$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await screenshot('home');
      await tester.tap(find.byKey(const ValueKey('radd-tab-4')));
      await tester.pumpAndSettle();
      final s = AppLocalizations.of(
        tester.element(find.byType(VolunteerWorkspace)),
      )!;
      expect(find.text(s.edit), findsNothing);
      expect(find.text(s.accountInformation), findsOneWidget);
      await screenshot('profile');
      await tester.ensureVisible(find.text(s.logout));
      await tester.tap(find.text(s.logout));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(s.logoutTitle), findsOneWidget);
      await screenshot('logout');
      await tester.tap(find.text(s.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
