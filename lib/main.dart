import 'package:flutter/material.dart';

import 'app/app_startup.dart';
import 'app/radd_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RaddApp(initialize: initializeApp));
}
