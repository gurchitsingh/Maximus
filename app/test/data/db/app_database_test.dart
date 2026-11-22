// Drift database against an in-memory SQLite (CONTRACTS 5, 10 "App data").
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/db/daos/settings_dao.dart';

void main() {
  late AppDatabase db;
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 11, 22, 9);
    db = AppDatabase(
      NativeDatabase.memory(),
      clock: () => now = now.add(const Duration(seconds: 1)),
    );
  });
  tearDown(() => db.close());

  test('schema version 1 and every 5.1 table exists', () async {
    expect(db.schemaVersion, 1);
    final names = db.allTables.map((t) => t.actualTableName).toSet();
    expect(names, {
      'settings',
      'interests',
      'study_list',
      'ratings',
      'lesson_progress',
      'quiz_results',
      'quiz_seen',
      'feed_state',
      'cached_docs',
      'cached_titles',
    });
  });

  group('settings', () {
    test('defaults are seeded on open, with a UUID v4 install id', () async {
      final s = await db.settingsDao.readAll();
      expect(s['theme'], 'dark');
      expect(s['text_size'], 'medium');
      expect(s['voice_speed'], '1.0');
      expect(s['voice_name'], '');
      expect(s['onboarding_done'], 'false');
      expect(
        s['install_id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('a written value survives re-seeding', () async {
      await db.settingsDao.write('theme', 'sepia');
      final id = await db.settingsDao.read('install_id');
      await db.settingsDao.seedDefaults();
      expect(await db.settingsDao.read('theme'), 'sepia');
      expect(await db.settingsDao.read('install_id'), id);
    });

    test('newInstallId is v4 and differs per call', () {
      final a = newInstallId(Random(1)), b = newInstallId(Random(2));
      expect(a, isNot(b));
      expect(a[14], '4');
    });
  });

  group('study list', () {
    test('newest first, add is idempotent, remove deletes', () async {
      final dao = db.userStateDao;
      await dao.addToStudyList('roman-history');
      await dao.addToStudyList('chanakya');
      await dao.addToStudyList('roman-history');
      var rows = await dao.watchStudyList().first;
      expect(rows.map((r) => r.titleId), ['chanakya', 'roman-history']);
      await dao.removeFromStudyList('chanakya');
      rows = await dao.watchStudyList().first;
      expect(rows.map((r) => r.titleId), ['roman-history']);
    });
  });

  group('ratings', () {
    test('one per title, null clears, newest first', () async {
      final dao = db.userStateDao;
      await dao.setRating('roman-history', 1);
      await dao.setRating('chanakya', -1);
      await dao.setRating('roman-history', 0);
      var rows = await dao.watchRatings().first;
      expect({for (final r in rows) r.titleId: r.value}, {
        'roman-history': 0,
        'chanakya': -1,
      });
      expect(rows.first.titleId, 'roman-history');
      await dao.setRating('roman-history', null);
      rows = await dao.watchRatings().first;
      expect(rows.map((r) => r.titleId), ['chanakya']);
    });
  });

  group('lesson progress', () {
    test('open keeps completion; complete stamps once', () async {
      final dao = db.userStateDao;
      await dao.openLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l01',
        lessonIndex: 1,
      );
      var rows = await dao.watchProgress().first;
      expect(rows.single.completedAt, isNull);

      await dao.completeLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l01',
        lessonIndex: 1,
      );
      rows = await dao.watchProgress().first;
      final firstDone = rows.single.completedAt;
      expect(firstDone, isNotNull);

      await dao.openLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l02',
        lessonIndex: 2,
      );
      await dao.completeLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l01',
        lessonIndex: 1,
      );
      rows = await dao.watchProgress().first;
      // Newest opened first: l01 was re-opened by the second completion.
      expect(rows.map((r) => r.lessonId), [
        'roman-history.l01',
        'roman-history.l02',
      ]);
      expect(rows.first.completedAt, firstDone);
      expect(rows.last.completedAt, isNull);
    });
  });

  test('clearMyData empties exactly the personal tables', () async {
    final dao = db.userStateDao;
    final oldId = await db.settingsDao.read('install_id');
    await db.settingsDao.write('theme', 'light');
    await dao.addToStudyList('roman-history');
    await dao.setRating('roman-history', 1);
    await dao.openLesson(
      titleId: 'roman-history',
      lessonId: 'roman-history.l01',
      lessonIndex: 1,
    );
    await db.into(db.interests).insert(
      InterestsCompanion.insert(
        titleId: 'roman-history',
        kind: 'topic_pick',
        position: 0,
        pickedAt: now,
      ),
    );
    await db.into(db.quizResults).insert(
      QuizResultsCompanion.insert(
        titleId: 'roman-history',
        score: 4,
        total: 6,
        questionIds: '[]',
        wrongIds: '[]',
        contentVersion: 1,
        takenAt: now,
      ),
    );
    await db.into(db.quizSeen).insert(
      QuizSeenCompanion.insert(
        questionId: 'roman-history.q001',
        titleId: 'roman-history',
        seenAt: now,
      ),
    );
    await db.into(db.feedState).insert(
      FeedStateCompanion.insert(
        factId: 'roman-history.f001',
        titleId: 'roman-history',
        updatedAt: now,
        saved: const Value(true),
      ),
    );
    await db.contentCacheDao.putTitle(
      titleId: 'roman-history',
      payload: '{}',
      contentVersion: 1,
    );
    await db.contentCacheDao.putDoc('catalogue', '{}');

    await db.clearMyData();

    for (final t in db.personalTables) {
      final n = await db.select(t).get();
      if (t.actualTableName == 'settings') {
        expect(n, hasLength(6), reason: 'settings re-seeded');
      } else {
        expect(n, isEmpty, reason: t.actualTableName);
      }
    }
    expect(await db.settingsDao.read('theme'), 'dark');
    expect(await db.settingsDao.read('install_id'), isNot(oldId));
    expect(await db.contentCacheDao.title('roman-history'), isNotNull);
    expect(await db.contentCacheDao.doc('catalogue'), isNotNull);
  });
}
