import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/theme/app_theme.dart';
import 'package:maximus/core/theme/tokens.dart';

/// Pixel 8 sized surface (about 412 x 915 dp).
void usePixel8(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(1080, 2400);
  addTearDown(tester.view.reset);
}

/// Wraps [child] in a themed MaterialApp + ProviderScope.
Widget themed(
  Widget child, {
  MxThemeVariant variant = MxThemeVariant.dark,
  bool reduceMotion = false,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: MxTheme.build(variant),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}
