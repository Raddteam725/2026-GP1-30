import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

(int, int) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: path);
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  test('The launcher shows the Radd name and Radd icons', () {
    expect(manifest, contains('android:label="Radd"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
  });

  test('Adaptive icons provide background, foreground and themed layers', () {
    for (final name in ['ic_launcher', 'ic_launcher_round']) {
      final xml = File('$_res/mipmap-anydpi-v26/$name.xml').readAsStringSync();
      expect(xml, contains('<adaptive-icon'), reason: name);
      expect(
        xml,
        contains('android:drawable="@color/ic_launcher_background"'),
        reason: name,
      );
      expect(
        xml,
        contains('android:drawable="@mipmap/ic_launcher_foreground"'),
        reason: name,
      );
      expect(
        xml,
        contains(
          '<monochrome android:drawable="@mipmap/ic_launcher_monochrome"',
        ),
        reason: name,
      );
    }
    expect(
      File('$_res/values/colors.xml').readAsStringSync(),
      contains('<color name="ic_launcher_background">#F9FBFD</color>'),
    );
  });

  test('Every density ships correctly sized launcher bitmaps', () {
    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      final folder = '$_res/mipmap-$density';
      final legacy = (48 * scale).round();
      final layer = (108 * scale).round();
      expect(_pngSize('$folder/ic_launcher.png'), (legacy, legacy));
      expect(_pngSize('$folder/ic_launcher_round.png'), (legacy, legacy));
      expect(_pngSize('$folder/ic_launcher_foreground.png'), (layer, layer));
      expect(_pngSize('$folder/ic_launcher_monochrome.png'), (layer, layer));
    }
  });

  test('The splash screen and application identity are unchanged', () {
    expect(
      File('$_res/values-v31/styles.xml').readAsStringSync(),
      contains('@drawable/launch_icon_blank'),
    );
    for (final path in [
      '$_res/drawable/launch_background.xml',
      '$_res/drawable-v21/launch_background.xml',
    ]) {
      expect(File(path).readAsStringSync(), isNot(contains('ic_launcher')));
    }
    final gradle = File('android/app/build.gradle.kts').existsSync()
        ? File('android/app/build.gradle.kts').readAsStringSync()
        : File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains('applicationId = "com.example.radd"'));
    expect(gradle, contains('namespace = "com.example.radd"'));
  });
}
