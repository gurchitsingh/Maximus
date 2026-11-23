// S9: Settings screen. Voice, Clear my data (keeps the content cache),
// About, Credits, all on the bundled fixtures (no network).
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/repositories/credits_repository.dart';
import 'package:maximus/features/settings/about_sheet.dart';
import 'package:maximus/features/settings/voice_sheet.dart';
import 'package:maximus/features/settings/voices.dart';

import '../app_harness.dart';
import '../helpers.dart';

/// Reads assets from disk synchronously (see SyncDevSource in the harness).
class FileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) {
    final bytes = File(key).readAsBytesSync();
    return Future.value(ByteData.sublistView(Uint8List.fromList(bytes)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      Future.value(File(key).readAsStringSync());

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(File(key).readAsStringSync());
}

class FileCreditsSource implements CreditsSource {
  FileCreditsSource({this.fail = false});
  bool fail;

  @override
  Future<String> creditsJson() => fail
      ? Future.error(const SocketException('offline'))
      : Future.value(File('assets/dev/credits.json').readAsStringSync());
}

class FakeVoices {
  static final voices = <TtsVoice>[
    const TtsVoice(name: 'en-us-x-a', locale: 'en-US', label: 'English (US) 1'),
    const TtsVoice(
      name: 'en-in-x-b',
      locale: 'en-IN',
      label: 'English (India) 1',
    ),
  ];
}

List<Override> _overrides({CreditsSource? credits}) => [
  creditsBundleProvider.overrideWithValue(FileBundle()),
  creditsSourceProvider.overrideWithValue(credits ?? FileCreditsSource()),
  ttsVoicesProvider.overrideWith((_) async => FakeVoices.voices),
];

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await AppHarness.settle(tester);
}

Future<void> openSettings(WidgetTester tester) =>
    tapAndSettle(tester, find.bySemanticsLabel('Settings'));

void main() {
  test('app version constant matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line, 'version: $appVersion+$appBuild');
  });

  test('parseVoices keeps English voices, numbers them per locale', () {
    final v = parseVoices([
      {'name': 'en-us-x-b', 'locale': 'en-US'},
      {'name': 'en-us-x-a', 'locale': 'en_US'},
      {'name': 'hi-in-x-a', 'locale': 'hi-IN'},
      {'name': 'en-in-x-a', 'locale': 'en-IN'},
      'junk',
    ]);
    expect(
      [for (final x in v) x.label],
      ['English (India) 1', 'English (US) 1', 'English (US) 2'],
    );
    expect(v[1].name, 'en-us-x-a');
    expect(parseVoices(null), isEmpty);
  });

  test('voiceRowValue falls back to Device default', () {
    expect(voiceRowValue('', FakeVoices.voices), 'Device default');
    expect(voiceRowValue('gone', FakeVoices.voices), 'Device default');
    expect(voiceRowValue('en-in-x-b', FakeVoices.voices), 'English (India) 1');
  });

  testWidgets('Settings lists Voice, Clear my data, About, Credits', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _overrides());
    await openSettings(tester);
    for (final t in [
      'Voice',
      'Device default',
      'Clear my data',
      'Topics, scores, settings',
      'About',
      'Version 1.0',
      'Credits',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await h.dispose(tester);
  });

  testWidgets('Voice: picking a voice saves it and speaks a sample', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _overrides());
    await openSettings(tester);
    await tapAndSettle(tester, find.text('Voice'));
    expect(find.text('English (US) 1'), findsOneWidget);
    await tapAndSettle(tester, find.text('English (India) 1'));
    final s = await AppHarness.run(tester, h.db.settingsDao.readAll);
    expect(s['voice_name'], 'en-in-x-b');
    expect(h.tts.spoken, [voiceSample]);
    await h.dispose(tester);
  });

  testWidgets('About shows the version', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _overrides());
    await openSettings(tester);
    await tapAndSettle(tester, find.text('About'));
    expect(find.text('About Maximus'), findsOneWidget);
    expect(find.text('$appVersion (build $appBuild)'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Credits: fonts, notices and per-title sources from fixtures', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _overrides());
    await openSettings(tester);
    await tapAndSettle(tester, find.text('Credits'));
    expect(find.text('Figtree'), findsOneWidget);
    expect(
      find.textContaining('Creative Commons Attribution-ShareAlike'),
      findsOneWidget,
    );
    expect(find.text('Connect to load content credits.'), findsNothing);
    // The fetched copy was cached for offline use.
    final cached = await AppHarness.run(
      tester,
      () => h.db.contentCacheDao.doc('credits'),
    );
    expect(cached, isNotNull);
    await h.dispose(tester);
  });

  testWidgets('Credits offline: cached copy, or fonts + connect message', (
    tester,
  ) async {
    usePixel8(tester);
    final source = FileCreditsSource(fail: true);
    final h = await AppHarness.pump(
      tester,
      overrides: _overrides(credits: source),
    );
    await openSettings(tester);
    await tapAndSettle(tester, find.text('Credits'));
    expect(find.text('Figtree'), findsOneWidget);
    expect(find.text('Connect to load content credits.'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Clear my data: Keep leaves everything, Clear empties it', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _overrides());
    final before = await AppHarness.run(tester, h.db.settingsDao.readAll);
    await AppHarness.run(tester, () async {
      await h.db.userStateDao.addToStudyList('roman-history');
      await h.db.settingsDao.write('theme', 'sepia');
      await h.db.contentCacheDao.putDoc('catalogue', '{}');
      await h.db.contentCacheDao.putTitle(
        titleId: 'roman-history',
        payload: '{}',
        contentVersion: 1,
      );
    });
    await openSettings(tester);

    // Cancel: nothing changes.
    await tapAndSettle(tester, find.text('Clear my data'));
    expect(find.text('Clear my data?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Keep my data'));
    expect(find.text('Clear my data?'), findsNothing);
    expect(
      await AppHarness.run(tester, () => h.db.select(h.db.studyList).get()),
      hasLength(1),
    );

    // Confirm: personal tables and settings reset, content cache stays,
    // a new install id is made, the app leaves Settings.
    await tapAndSettle(tester, find.text('Clear my data'));
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Clear my data'),
      ),
    );
    expect(
      await AppHarness.run(tester, () => h.db.select(h.db.studyList).get()),
      isEmpty,
    );
    final after = await AppHarness.run(tester, h.db.settingsDao.readAll);
    expect(after['theme'], 'dark');
    expect(after['install_id'], isNot(before['install_id']));
    expect(
      await AppHarness.run(tester, () => h.db.contentCacheDao.doc('catalogue')),
      isNotNull,
    );
    expect(
      await AppHarness.run(
        tester,
        () => h.db.contentCacheDao.title('roman-history'),
      ),
      isNotNull,
    );
    // Back at the start route (Home until S5 adds the splash).
    expect(find.text('Settings'), findsNothing);
    await h.dispose(tester);
  });

  test(
    'credits repository: fresh copy cached, cache used when offline',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CreditsRepository(db, FileCreditsSource(), FileBundle());
      final fresh = await repo.content();
      expect(fresh!.titles.map((t) => t.id), contains('roman-history'));
      final offline = CreditsRepository(
        db,
        FileCreditsSource(fail: true),
        FileBundle(),
      );
      expect((await offline.content())!.images, hasLength(fresh.images.length));
      // Corrupt cache and offline: no content, no crash.
      await db.contentCacheDao.putDoc('credits', jsonEncode({'x': 1}));
      expect(await offline.content(), isNull);
      expect((await offline.fonts()).map((f) => f.family), contains('Cinzel'));
    },
  );
}
