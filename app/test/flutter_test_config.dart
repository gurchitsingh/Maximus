// Loaded automatically before every test file in test/.
// Registers the bundled fonts so layout and overflow checks use real glyph
// metrics instead of the square test font.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const families = {
    'Figtree': 'assets/fonts/Figtree',
    'Cinzel': 'assets/fonts/Cinzel',
    'Caveat Brush': 'assets/fonts/CaveatBrush',
    'Big Shoulders Stencil Display': 'assets/fonts/BigShouldersStencil',
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final f in Directory(entry.value).listSync()) {
      if (f.path.endsWith('.ttf')) {
        final bytes = File(f.path).readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
    }
    await loader.load();
  }
  await testMain();
}
