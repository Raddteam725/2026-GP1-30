import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app_startup.dart';
import 'app/radd_app.dart';
import 'features/guardian/data/guardian_push_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Registered before runApp per FlutterFire's requirement, independent of
  // whether the Guardian has granted notification permission or has any
  // registration at all -- setting the handler itself is always safe.
  FirebaseMessaging.onBackgroundMessage(guardianBackgroundMessageHandler);
  // waitForFirstFrame: the splash animation's clock starts when the first
  // frame has really been rasterized (the moment Android drops its launch
  // window), so the animation is the first branded thing the user sees.
  runApp(const RaddApp(initialize: initializeApp, waitForFirstFrame: true));
}
