import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/gallery/gallery_samples.dart';
import 'package:maximus/core/widgets/widgets.dart';

import '../../helpers.dart';

void main() {
  testWidgets('no art: tinted gradient with both lettering lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(const PosterCard(data: GallerySamples.roman, width: 128)),
    );
    expect(find.byType(TintedGradient), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('ROMAN'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
    expect(tester.getSize(find.byType(PosterCard)), const Size(128, 192));
  });

  testWidgets('match badge counts up to the value and is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        PosterCard(data: GallerySamples.roman, matchPercent: 94, onTap: () {}),
      ),
    );
    // Mid-animation the label is below the target.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('94% match'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('94% match'), findsOneWidget);
    expect(find.bySemanticsLabel('ROMAN HISTORY, 94% match'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('reduced motion shows the final value at once', (tester) async {
    await tester.pumpWidget(
      themed(
        const PosterCard(data: GallerySamples.roman, matchPercent: 94),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('94% match'), findsOneWidget);
  });

  testWidgets('compact badge drops the word "match"', (tester) async {
    await tester.pumpWidget(
      themed(
        const PosterCard(
          data: GallerySamples.egypt,
          width: 170,
          matchPercent: 96,
          compactBadge: true,
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('96%'), findsOneWidget);
  });

  testWidgets('tap fires; display-only poster is not dimmed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      themed(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PosterCard(
              key: const Key('tap'),
              data: GallerySamples.ww2,
              onTap: () => taps++,
            ),
            const PosterCard(key: Key('still'), data: GallerySamples.french),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('tap')));
    expect(taps, 1);
    final dimmed = find.descendant(
      of: find.byKey(const Key('still')),
      matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
    );
    expect(dimmed, findsNothing);
  });

  test('lettering size follows the 2.4 formulas', () {
    // roman, len 7, w 128: min(0.115w, 0.9w / (len * 0.86)) = 14.72
    expect(
      PosterLettering.fontSizeFor(MxLettering.roman, ['ROMAN', 'HISTORY'], 128),
      closeTo(14.72, 1e-9),
    );
    // carved, len 7, w 128: min(0.085w, 0.9w / len) = 10.88
    expect(
      PosterLettering.fontSizeFor(MxLettering.carved, [
        'ANCIENT',
        'EGYPT',
      ], 128),
      closeTo(10.88, 1e-9),
    );
    // Short lines use len 4 as the floor.
    expect(
      PosterLettering.fontSizeFor(MxLettering.stencil, ['WW', 'II'], 100),
      closeTo(22, 1e-9),
    );
    expect(MxLettering.parse('brush'), MxLettering.brush);
    expect(MxLettering.parse('unknown'), MxLettering.carved);
  });
}
