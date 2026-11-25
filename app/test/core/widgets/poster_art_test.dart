import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/widgets/poster_art.dart';

const _fallbackKey = ValueKey('poster-fallback');

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(child: SizedBox(width: 200, child: child)),
      ),
    );

String? _svgAsset(WidgetTester tester) {
  final pic = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return (pic.bytesLoader as SvgAssetLoader).assetName;
}

Finder _wash(Gradient g) => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).gradient.runtimeType == g.runtimeType &&
      w.key == null,
);

void main() {
  late PosterManifest manifest;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    manifest = PosterManifest.parse(
      await rootBundle.loadString(PosterManifest.assetPath),
    );
  });

  test('manifest covers the 19 drawn posters with the contract modes', () {
    expect(manifest.entries.length, 19);
    expect(manifest['roman-history']!.mode, PosterMode.pair);
    expect(manifest['ancient-egypt']!.mode, PosterMode.pair);
    for (final id in ['ww1', 'ww2', 'cold-war', 'american-civil-war']) {
      expect(manifest[id]!.mode, PosterMode.single, reason: id);
    }
    expect(manifest['vikings']!.mode, PosterMode.wash);
    expect(manifest['napoleon']!.mode, PosterMode.wash);
    expect(manifest['roman-history']!.lines, ['ROMAN', 'HISTORY']);
  });

  for (final b in Brightness.values) {
    final dark = b == Brightness.dark;

    testWidgets('pair loads ${dark ? 'evening' : 'day'} with no overlay ($b)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PosterArt(titleId: 'roman-history', manifest: manifest),
          brightness: b,
        ),
      );
      await tester.pump();
      expect(
        _svgAsset(tester),
        'assets/posters/roman-history.${dark ? 'evening' : 'day'}.svg',
      );
      expect(_wash(const LinearGradient(colors: [])), findsNothing);
      expect(_wash(const RadialGradient(colors: [])), findsNothing);
    });

    testWidgets(
      'wash loads one svg plus the ${dark ? 'dusk' : 'sun'} overlay',
      (tester) async {
        await tester.pumpWidget(
          _host(
            PosterArt(titleId: 'vikings', manifest: manifest),
            brightness: b,
          ),
        );
        await tester.pump();
        expect(_svgAsset(tester), 'assets/posters/vikings.svg');
        expect(
          _wash(const LinearGradient(colors: [])),
          dark ? findsOneWidget : findsNothing,
        );
        expect(
          _wash(const RadialGradient(colors: [])),
          dark ? findsNothing : findsOneWidget,
        );
      },
    );

    testWidgets('single is the same in both themes, no overlay ($b)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PosterArt(titleId: 'ww2', manifest: manifest),
          brightness: b,
        ),
      );
      await tester.pump();
      expect(_svgAsset(tester), 'assets/posters/ww2.svg');
      expect(_wash(const LinearGradient(colors: [])), findsNothing);
      expect(_wash(const RadialGradient(colors: [])), findsNothing);
    });
  }

  for (final crop in PosterCrop.values) {
    testWidgets('crop ${crop.name} has its aspect and offsets the artboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PosterArt(
            titleId: 'french-revolution',
            crop: crop,
            manifest: manifest,
          ),
        ),
      );
      await tester.pump();
      final box = tester.getSize(find.byType(PosterArt));
      expect(box.width / box.height, closeTo(crop.width / crop.height, 1e-6));
      final pos = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(SvgPicture),
          matching: find.byType(Positioned),
        ),
      );
      final scale = box.width / crop.width;
      expect(pos.left, closeTo(-crop.x * scale, 1e-6));
      expect(pos.top, closeTo(-crop.y * scale, 1e-6));
      expect(pos.width, closeTo(200 * scale, 1e-6));
    });
  }

  testWidgets('loads the manifest from the asset bundle when none is given', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PosterArt(titleId: 'ancient-greece')));
    await tester.runAsync(() => PosterManifest.load(rootBundle));
    await tester.pump();
    await tester.pump();
    expect(_svgAsset(tester), 'assets/posters/ancient-greece.svg');
  });

  testWidgets('title with no poster draws the fallback from caller colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PosterArt(
          titleId: 'black-death',
          manifest: manifest,
          fallbackBg: const Color(0xFF112233),
          fallbackTint: const Color(0xFFAA5500),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsNothing);
    final deco = tester.widget<DecoratedBox>(find.byKey(_fallbackKey));
    final g = (deco.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(g.colors.last, const Color(0xFF112233));
  });

  testWidgets('manifest entry whose file is missing falls back to its bg', (
    tester,
  ) async {
    final m = PosterManifest({
      'ghost': const PosterEntry(
        mode: PosterMode.single,
        bg: Color(0xFF445566),
        tint: Color(0xFFCCBB99),
      ),
    });
    await tester.pumpWidget(_host(PosterArt(titleId: 'ghost', manifest: m)));
    await tester.pumpAndSettle();
    expect(find.byKey(_fallbackKey), findsOneWidget);
    final deco = tester.widget<DecoratedBox>(find.byKey(_fallbackKey));
    final g = (deco.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(g.colors.last, const Color(0xFF445566));
  });
}
