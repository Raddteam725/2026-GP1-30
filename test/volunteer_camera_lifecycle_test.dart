import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radd/core/localization/generated/app_localizations.dart';
import 'package:radd/features/volunteer/presentation/volunteer_capture.dart';

class FailingCamera extends CameraPlatform {
  int created = 0, disposed = 0;
  Completer<void>? initialization;
  @override
  Future<List<CameraDescription>> availableCameras() async => [
    const CameraDescription(
      name: 'test',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings settings,
  ) async => ++created;
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) =>
      StreamController<CameraInitializedEvent>().stream;
  @override
  Stream<CameraErrorEvent> onCameraError(int id) =>
      StreamController<CameraErrorEvent>().stream;
  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (initialization != null) await initialization!.future;
    throw PlatformException(code: 'CameraAccessDenied');
  }

  @override
  Future<void> dispose(int id) async {
    disposed++;
    throw PlatformException(code: 'IllegalStateException');
  }
}

void main() {
  late CameraPlatform previous;
  late FailingCamera camera;
  setUp(() {
    previous = CameraPlatform.instance;
    camera = FailingCamera();
    CameraPlatform.instance = camera;
  });
  tearDown(() => CameraPlatform.instance = previous);
  Widget screen() => const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: VolunteerCapture(),
  );
  testWidgets('Failed native initialization and disposal remain retryable', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(
      find.text('The camera is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(camera.disposed, 1);
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(camera.created, 2);
    expect(camera.disposed, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Permission lifecycle does not dispose initializing controller', (
    tester,
  ) async {
    camera.initialization = Completer<void>();
    await tester.pumpWidget(screen());
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(camera.created, 1);
    expect(camera.disposed, 0);
    camera.initialization!.complete();
    await tester.pumpAndSettle();
    expect(camera.disposed, 1);
    expect(tester.takeException(), isNull);
  });
}
