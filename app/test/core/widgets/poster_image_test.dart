import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/widgets/widgets.dart';

const _fallbackKey = ValueKey('screen-fallback');
const _fallback = ColoredBox(key: _fallbackKey, color: Color(0xFF123456));

Widget _host(Widget child, Brightness b, {Size size = const Size(160, 240)}) =>
    MaterialApp(
      theme: ThemeData(brightness: b),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );

String _asset(WidgetTester tester) {
  final pic = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return (pic.bytesLoader as SvgAssetLoader).assetName;
}

void main() {
  late PosterManifest manifest;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    manifest = PosterManifest.parse(
      await rootBundle.loadString(PosterManifest.assetPath),
    );
  });

  const sizes = {
    PosterCrop.poster: Size(160, 240),
    PosterCrop.banner: Size(300, 150),
    PosterCrop.square: Size(64, 64),
  };
  // title id -> [light asset, dark asset]
  const bundled = {
    'roman-history': [
      'assets/posters/roman-history.day.svg',
      'assets/posters/roman-history.evening.svg',
    ],
    'vikings': ['assets/posters/vikings.svg', 'assets/posters/vikings.svg'],
    'ww1': ['assets/posters/ww1.svg', 'assets/posters/ww1.svg'],
  };

  for (final b in Brightness.values) {
    for (final crop in PosterCrop.values) {
      for (final e in bundled.entries) {
        testWidgets('PosterImage ${e.key} draws bundled art ($b, $crop)', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              PosterImage(
                titleId: e.key,
                crop: crop,
                fallback: _fallback,
                manifest: manifest,
              ),
              b,
              size: sizes[crop]!,
            ),
          );
          await tester.pump();
          expect(find.byType(BundledPosterArt), findsOneWidget);
          expect(find.byKey(_fallbackKey), findsNothing);
          expect(_asset(tester), e.value[b == Brightness.dark ? 1 : 0]);
          expect(
            tester.getSize(find.byType(PosterImage)),
            sizes[crop]!,
            reason: 'art fills its slot',
          );
        });
      }

      testWidgets('PosterImage without a poster falls back ($b, $crop)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            PosterImage(
              titleId: 'black-death',
              crop: crop,
              fallback: _fallback,
              manifest: manifest,
            ),
            b,
            size: sizes[crop]!,
          ),
        );
        await tester.pump();
        expect(find.byType(BundledPosterArt), findsNothing);
        expect(find.byKey(_fallbackKey), findsOneWidget);
      });
    }
  }

  testWidgets('PosterImage with no title id shows the fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PosterImage(titleId: null, fallback: _fallback, manifest: manifest),
        Brightness.light,
      ),
    );
    expect(find.byKey(_fallbackKey), findsOneWidget);
  });

  testWidgets('PosterImage loads the manifest from the bundle itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const PosterImage(titleId: 'ww2', fallback: _fallback),
        Brightness.dark,
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byType(BundledPosterArt), findsOneWidget);
  });

  group('callers', () {
    for (final b in Brightness.values) {
      testWidgets('TitleArt with a crop uses bundled art ($b)', (tester) async {
        await tester.pumpWidget(
          _host(
            const TitleArt(
              data: ArtData(
                bg: Color(0xFF000000),
                tint: Color(0xFFFFFFFF),
                titleId: 'ancient-egypt',
                crop: PosterCrop.banner,
              ),
            ),
            b,
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        expect(find.byType(BundledPosterArt), findsOneWidget);
        expect(
          _asset(tester),
          'assets/posters/ancient-egypt.${b == Brightness.dark ? 'evening' : 'day'}.svg',
        );
      });

      testWidgets('TitleArt keeps its look with no crop or no poster ($b)', (
        tester,
      ) async {
        for (final data in const [
          ArtData(
            bg: Color(0xFF000000),
            tint: Color(0xFFFFFFFF),
            titleId: 'ww1', // has a poster, but the slot did not opt in
          ),
          ArtData(
            bg: Color(0xFF000000),
            tint: Color(0xFFFFFFFF),
            titleId: 'black-death',
            crop: PosterCrop.square,
          ),
        ]) {
          await tester.pumpWidget(_host(TitleArt(data: data), b));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
          expect(find.byType(BundledPosterArt), findsNothing);
          expect(find.byType(TintedGradient), findsOneWidget);
        }
      });

      testWidgets('PosterCard uses bundled art, else the gradient ($b)', (
        tester,
      ) async {
        PosterData data(String id) => PosterData(
          lines: const ['A', 'B'],
          lettering: MxLettering.parse('roman'),
          bg: const Color(0xFF000000),
          tint: const Color(0xFFFFFFFF),
          titleId: id,
        );
        await tester.pumpWidget(
          _host(PosterCard(data: data('napoleon'), width: 128), b),
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        expect(find.byType(BundledPosterArt), findsOneWidget);
        expect(find.byType(TintedGradient), findsNothing);

        await tester.pumpWidget(
          _host(PosterCard(data: data('sikh-history'), width: 128), b),
        );
        await tester.pump();
        expect(find.byType(BundledPosterArt), findsNothing);
        expect(find.byType(TintedGradient), findsOneWidget);
      });
    }
  });
}
