import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app_startup.dart';
import 'app/radd_app.dart';
import 'features/guardian/data/guardian_push_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(guardianBackgroundMessageHandler);
  runApp(const RaddApp(initialize: initializeApp, waitForFirstFrame: true));
}
