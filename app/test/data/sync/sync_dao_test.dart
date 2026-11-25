// SyncDao (CONTRACTS 15.1, 15.3, 15.5): row <-> record, last write wins on
// pull, tombstones, and `dirty` cleared only for the version the server
// acknowledged.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/sync/sync_record.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  var now = DateTime.utc(2026, 11, 25, 10);

  setUp(() async {
    now = DateTime.utc(2026, 11, 25, 10);
    db = AppDatabase(NativeDatabase.memory(), clock: () => now);
    await db.settingsDao.readAll(); // opens and seeds
  });
  tearDown(() => db.close());

  Future<RatingRow?> rating(String id) => (db.select(
    db.ratings,
  )..where((t) => t.titleId.equals(id))).getSingleOrNull();

  SyncRecord remoteRating(int value, DateTime at, {String id = 'chanakya'}) =>
      SyncRecord(
        kind: SyncKind.rating,
        id: id,
        data: {'title_id': id, 'value': value, 'rated_at': zTime(at)},
        updatedAt: at,
      );

  group('records match CONTRACTS 15.1', () {
    test('every kind, ids and data keys', () async {
      final d = db.userStateDao;
      await d.addToStudyList('roman-history');
      await d.setRating('roman-history', 1);
      await d.completeLesson(
        titleId: 'roman-history',
        lessonId: 'roman-history.l01',
        lessonIndex: 1,
      );
      await d.setInterests('topic_pick', ['roman-history']);
      await d.toggleFactSaved(
        factId: 'roman-history.f001',
        titleId: 'roman-history',
      );
      await db.settingsDao.write(SettingKeys.theme, 'light');
      await db.settingsDao.write(SettingKeys.installId, 'never-synced');
      final records = {
        for (final r in await db.syncDao.dirtyRecords()) '${r.kind}/${r.id}': r,
      };
      expect(records.keys, unorderedEquals([
        'study_item/roman-history',
        'rating/roman-history',
        'progress/roman-history.l01',
        'interest/topic_pick:roman-history',
        'feed_item/roman-history.f001',
        'setting/theme',
      ]));
      expect(records['setting/theme']!.data, {'value': 'light'});
      expect(records['rating/roman-history']!.data!.keys, {
        'title_id',
        'value',
        'rated_at',
      });
      expect(records['progress/roman-history.l01']!.data, {
        'lesson_id': 'roman-history.l01',
        'title_id': 'roman-history',
        'lesson_index': 1,
        'last_opened_at': '2026-11-25T10:00:00.000Z',
        'completed_at': '2026-11-25T10:00:00.000Z',
      });
      expect(records['interest/topic_pick:roman-history']!.data, {
        'kind': 'topic_pick',
        'title_id': 'roman-history',
        'position': 0,
        'picked_at': '2026-11-25T10:00:00.000Z',
      });
      expect(records['feed_item/roman-history.f001']!.data, {
        'fact_id': 'roman-history.f001',
        'title_id': 'roman-history',
        'saved': true,
        'reaction': 0,
        'seen_at': null,
      });
      final json = records['study_item/roman-history']!.toJson();
      expect(json.keys, {'kind', 'id', 'data', 'updated_at', 'deleted'});
      expect(json['updated_at'], '2026-11-25T10:00:00.000Z');
    });

    test('a quiz result is a UUID v4 record', () async {
      await db
          .into(db.quizResults)
          .insert(
            QuizResultsCompanion.insert(
              titleId: 'roman-history',
              score: 5,
              total: 6,
              questionIds: '["roman-history.q001"]',
              wrongIds: '[]',
              contentVersion: 2,
              takenAt: now,
            ),
          );
      final r = (await db.syncDao.dirtyRecords()).single;
      expect(r.kind, SyncKind.quizResult);
      expect(r.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(r.data!['id'], r.id);
      expect(r.data!['question_ids'], ['roman-history.q001']);
    });

    test('seeded defaults are clean, so a fresh phone pushes nothing', () async {
      expect(await db.syncDao.dirtyCount(), 0);
    });
  });

  group('local writes', () {
    test('a delete is a dirty tombstone hidden from reads', () async {
      await db.userStateDao.addToStudyList('roman-history');
      await db.userStateDao.removeFromStudyList('roman-history');
      expect(await db.userStateDao.watchStudyList().first, isEmpty);
      final r = (await db.syncDao.dirtyRecords()).single;
      expect((r.kind, r.deleted, r.data), (SyncKind.studyItem, true, null));
    });

    test('a clock that went back still stamps after the stored change', () {
      return () async {
        await db.userStateDao.setRating('roman-history', 1);
        now = now.subtract(const Duration(hours: 1));
        await db.userStateDao.setRating('roman-history', -1);
        final r = (await rating('roman-history'))!;
        expect(r.value, -1);
        expect(
          r.updatedAt,
          DateTime.utc(2026, 11, 25, 10).add(const Duration(milliseconds: 1)),
        );
      }();
    });
  });

  group('pull: last write wins (15.3)', () {
    test('a newer server record replaces the local row and is clean', () async {
      await db.userStateDao.setRating('chanakya', 1);
      final later = now.add(const Duration(minutes: 1));
      expect(await db.syncDao.applyPulled(remoteRating(-1, later)), isTrue);
      final r = (await rating('chanakya'))!;
      expect((r.value, r.dirty, r.updatedAt), (-1, false, later));
    });

    test('an older server record loses; the local edit stays dirty', () async {
      await db.userStateDao.setRating('chanakya', 1);
      final earlier = now.subtract(const Duration(minutes: 1));
      expect(await db.syncDao.applyPulled(remoteRating(-1, earlier)), isFalse);
      final r = (await rating('chanakya'))!;
      expect((r.value, r.dirty), (1, true));
    });

    test('same instant: a delete beats an edit, an edit never beats a '
        'delete', () async {
      await db.userStateDao.setRating('chanakya', 1);
      final at = (await rating('chanakya'))!.updatedAt;
      expect(
        await db.syncDao.applyPulled(
          SyncRecord.tombstone(
            kind: SyncKind.rating,
            id: 'chanakya',
            updatedAt: at,
          ),
        ),
        isTrue,
      );
      expect(await rating('chanakya'), isNull);

      await db.userStateDao.setRating('cold-war', 1);
      await db.userStateDao.setRating('cold-war', null); // local tombstone
      final tomb = (await rating('cold-war'))!;
      expect(
        await db.syncDao.applyPulled(
          remoteRating(1, tomb.updatedAt, id: 'cold-war'),
        ),
        isFalse,
      );
      expect((await rating('cold-war'))!.deleted, isTrue);
    });

    test('a pulled tombstone removes the row; unknown rows stay absent', () async {
      await db.userStateDao.addToStudyList('roman-history');
      final later = now.add(const Duration(seconds: 1));
      for (final id in ['roman-history', 'never-here']) {
        await db.syncDao.applyPulled(
          SyncRecord.tombstone(
            kind: SyncKind.studyItem,
            id: id,
            updatedAt: later,
          ),
        );
      }
      expect(await db.select(db.studyList).get(), isEmpty);
    });

    test('quiz results are append-only', () async {
      const id = '0b7c6a52-6d0e-4f43-9a51-2a8f0c1d2e3f';
      SyncRecord quiz(int score, DateTime at) => SyncRecord(
        kind: SyncKind.quizResult,
        id: id,
        data: {
          'id': id,
          'title_id': 'roman-history',
          'score': score,
          'total': 6,
          'question_ids': <String>[],
          'wrong_ids': <String>[],
          'content_version': 1,
          'taken_at': zTime(at),
        },
        updatedAt: at,
      );
      expect(await db.syncDao.applyPulled(quiz(4, now)), isTrue);
      final later = now.add(const Duration(hours: 1));
      expect(await db.syncDao.applyPulled(quiz(6, later)), isFalse);
      expect((await db.select(db.quizResults).getSingle()).score, 4);
      await db.syncDao.applyPulled(
        SyncRecord.tombstone(
          kind: SyncKind.quizResult,
          id: id,
          updatedAt: now,
        ),
      );
      expect(await db.select(db.quizResults).get(), isEmpty);
    });

    test('settings: install_id and unknown keys are ignored', () async {
      final at = now.add(const Duration(days: 1));
      for (final key in ['install_id', 'favourite_colour']) {
        expect(
          await db.syncDao.applyPulled(
            SyncRecord(
              kind: SyncKind.setting,
              id: key,
              data: {'value': 'x'},
              updatedAt: at,
            ),
          ),
          isFalse,
        );
      }
      expect(await db.settingsDao.read('install_id'), isNot('x'));
      expect(await db.settingsDao.read('favourite_colour'), isNull);
    });
  });

  group('acknowledgements', () {
    test('ack clears dirty; an acked tombstone is removed for good', () async {
      await db.userStateDao.addToStudyList('roman-history');
      await db.userStateDao.setRating('chanakya', 1);
      await db.userStateDao.setRating('chanakya', null);
      for (final r in await db.syncDao.dirtyRecords()) {
        await db.syncDao.ackApplied(r);
      }
      expect(await db.syncDao.dirtyCount(), 0);
      expect(await db.select(db.studyList).get(), hasLength(1));
      expect(await db.select(db.ratings).get(), isEmpty);
    });

    test('a change made while the push was in flight stays dirty', () async {
      await db.userStateDao.setRating('chanakya', 1);
      final pushed = (await db.syncDao.dirtyRecords()).single;
      now = now.add(const Duration(seconds: 2));
      await db.userStateDao.setRating('chanakya', -1);
      await db.syncDao.ackApplied(pushed);
      final r = (await rating('chanakya'))!;
      expect((r.value, r.dirty), (-1, true));

      // Superseded by the server: also ignored while a newer edit waits.
      await db.syncDao.applySuperseded(
        pushed,
        remoteRating(1, now.add(const Duration(days: 1))),
      );
      expect((await rating('chanakya'))!.value, -1);
    });

    test('superseded: the server copy overwrites the pushed row', () async {
      await db.userStateDao.setRating('chanakya', 1);
      final pushed = (await db.syncDao.dirtyRecords()).single;
      final stored = remoteRating(-1, now.add(const Duration(minutes: 5)));
      await db.syncDao.applySuperseded(pushed, stored);
      final r = (await rating('chanakya'))!;
      expect((r.value, r.dirty), (-1, false));
    });
  });

  test('Clear my data tombstones every synced row and resets settings as '
      'changes', () async {
    await db.userStateDao.addToStudyList('roman-history');
    await db.userStateDao.setRating('chanakya', 1);
    await db.settingsDao.write(SettingKeys.theme, 'light');
    for (final r in await db.syncDao.dirtyRecords()) {
      await db.syncDao.ackApplied(r);
    }
    final oldId = await db.settingsDao.read(SettingKeys.installId);
    now = now.add(const Duration(minutes: 1));
    await db.clearMyData();
    final records = await db.syncDao.dirtyRecords();
    final byKind = {for (final r in records) '${r.kind}/${r.id}': r};
    expect(byKind['study_item/roman-history']!.deleted, isTrue);
    expect(byKind['rating/chanakya']!.deleted, isTrue);
    expect(byKind['setting/theme']!.data, {'value': 'dark'});
    expect(byKind['setting/onboarding_done']!.data, {'value': 'false'});
    expect(byKind.keys.where((k) => k.contains('install_id')), isEmpty);
    expect(await db.settingsDao.read(SettingKeys.installId), isNot(oldId));
    expect(await db.userStateDao.watchStudyList().first, isEmpty);
  });

  test('incomingWins is the server rule', () {
    final t = DateTime.utc(2026);
    final later = t.add(const Duration(milliseconds: 1));
    bool wins(DateTime a, bool ad, DateTime b, bool bd) => incomingWins(
      incomingAt: a,
      incomingDeleted: ad,
      localAt: b,
      localDeleted: bd,
    );
    expect(wins(later, false, t, false), isTrue);
    expect(wins(t, false, later, false), isFalse);
    expect(wins(t, true, t, false), isTrue);
    expect(wins(t, false, t, true), isFalse);
    expect(wins(t, false, t, false), isFalse);
  });
}
