import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/radd_app.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final preferences = await SharedPreferences.getInstance();
  final language = preferences.getString('radd.language');
  runApp(RaddApp(locale: language == null ? null : Locale(language)));
}
