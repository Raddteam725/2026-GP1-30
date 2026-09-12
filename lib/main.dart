import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/radd_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Keep this first implementation English; locale switching comes later.
  runApp(const RaddApp(locale: Locale('en')));
}
