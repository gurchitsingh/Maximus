// Pumps the whole app on an in-memory drift database with a fake TTS
// engine. Content comes from the bundled assets/dev samples.
import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/app/app.dart';
import 'package:maximus/core/theme/theme_controller.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/providers.dart';
import 'package:maximus/data/repositories/content_source.dart';
import 'package:maximus/features/reader/read_aloud.dart';

class FakeTts implements TtsEngine {
  final spoken = <String>[];
  int stops = 0;

  @override
  Future<void> speak(
    String text, {
    required double speed,
    String? voiceName,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async => stops++;
}

/// The same assets/dev files, read synchronously. rootBundle caches load
/// futures across tests, and a future from an earlier test's fake-async
/// zone never completes in the next one.
class SyncDevSource implements ContentSource {
  @override
  Future<String> catalogueJson() =>
      Future.value(File('assets/dev/catalogue.json').readAsStringSync());

  @override
  Future<String> titleJson(String id) {
    final f = File('assets/dev/$id.json');
    if (!f.existsSync()) return Future.error(TitleNotFound(id));
    return Future.value(f.readAsStringSync());
  }
}

class AppHarness {
  AppHarness._(this.db, this.tts);

  final AppDatabase db;
  final FakeTts tts;

  static Future<AppHarness> pump(
    WidgetTester tester, {
    AppDatabase? db,
    List<Override> overrides = const [],
    ContentSource? contentSource,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final h = AppHarness._(
      db ?? AppDatabase(NativeDatabase.memory()),
      FakeTts(),
    );
    final stored = await run(tester, h.db.settingsDao.readAll);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(h.db),
          ttsEngineProvider.overrideWithValue(h.tts),
          contentSourceProvider.overrideWithValue(
            contentSource ?? SyncDevSource(),
          ),
          initialThemeSettingsProvider.overrideWithValue(
            ThemeSettings.fromStored(stored),
          ),
          settingsWriterProvider.overrideWithValue(h.db.settingsDao),
          ...overrides,
        ],
        child: const MaximusApp(),
      ),
    );
    // Runs even when the test fails, so the next test starts clean.
    addTearDown(() => h.dispose(tester));
    await settle(tester);
    return h;
  }

  /// Runs a drift call to completion. The database lives in the test's
  /// fake-async zone, so its futures finish only while frames are pumped
  /// (tester.runAsync would wait forever).
  static Future<T> run<T>(WidgetTester tester, Future<T> Function() f) async {
    late T result;
    Object? error;
    var done = false;
    f().then(
      (v) {
        result = v;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    for (var i = 0; i < 200 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    if (error != null) throw error!;
    if (!done) throw StateError('database call did not finish');
    return result;
  }

  /// Lets drift streams, asset loads and the frame pipeline finish.
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  bool _disposed = false;

  Future<void> dispose(WidgetTester tester) async {
    if (_disposed) return;
    _disposed = true;
    // Unmount first so drift stream listeners are cancelled, then close.
    await tester.pumpWidget(const SizedBox.shrink());
    // Let fire-and-forget writes (settings) land before closing.
    await settle(tester);
    try {
      await run(tester, db.close);
    } catch (_) {
      // Closing is cleanup only; the in-memory database dies with the
      // isolate anyway.
    }
  }
}
