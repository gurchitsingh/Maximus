import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/gallery/gallery_screen.dart';
import 'package:maximus/core/theme/theme_controller.dart';
import 'package:maximus/core/theme/tokens.dart';

import 'app_harness.dart';
import 'helpers.dart';

void main() {
  testWidgets('tabs switch screens and Settings switches the theme', (
    tester,
  ) async {
    usePixel8(tester);
    await AppHarness.pump(tester);
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Library'));
    await AppHarness.settle(tester);
    expect(find.text('FEATURED'), findsOneWidget);

    await tester.tap(find.text('Study'));
    await AppHarness.settle(tester);
    expect(find.text('Study list'), findsWidgets);

    await tester.tap(find.text('Home'));
    await AppHarness.settle(tester);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await AppHarness.settle(tester);
    expect(find.text('THEME'), findsOneWidget);

    await tester.tap(find.text('Sepia'));
    await AppHarness.settle(tester);
    final ctx = tester.element(find.text('THEME'));
    expect(Theme.of(ctx).extension<MxColors>(), MxColors.sepia);
    final container = ProviderScope.containerOf(ctx);
    expect(container.read(themeSettingsProvider).variant, MxThemeVariant.sepia);
  });

  for (final variant in MxThemeVariant.values) {
    testWidgets('gallery renders every section in ${variant.name}', (
      tester,
    ) async {
      usePixel8(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeSettingsProvider.overrideWith(
              () => _Fixed(ThemeSettings(variant: variant)),
            ),
          ],
          child: const MaterialApp(home: GalleryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      // Scroll to the last section; any overflow or build error fails here.
      // Fixed pumps, not pumpAndSettle: skeletons and the spinner loop.
      await tester.scrollUntilVisible(
        find.text('Maximus'),
        600,
        scrollable: list,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Maximus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gallery opens the title sheet modal', (tester) async {
    usePixel8(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GalleryScreen())),
    );
    await tester.pumpAndSettle();
    final open = find.text('Open title sheet');
    await tester.scrollUntilVisible(
      open,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(open);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(open);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('8 lessons · 48 min'), findsOneWidget);
    expect(find.text('Add to study list'), findsWidgets);
  });
}

class _Fixed extends ThemeSettingsController {
  _Fixed(this.initial);
  final ThemeSettings initial;

  @override
  ThemeSettings build() => initial;
}
