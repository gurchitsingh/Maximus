// Drift upgrade paths (CONTRACTS 5.2, 10): every old schema to the current
// one, with the data checked after the upgrade. Helpers come from
//   dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/sync/sync_dao.dart';
import 'package:maximus/data/sync/sync_record.dart';

import '../../generated_migrations/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  // v1 stores DateTime as unix seconds.
  const opened = 1764000000; // 2025-11-24T16:00:00Z
  const done = 1764000600;
  DateTime ms(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  test('v1 to v2: schema matches a fresh v2 database', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('v1 to v2 keeps every row and adds the sync columns', () async {
    final schema = await verifier.schemaAt(1);
    void sql(String s) => schema.rawDatabase.execute(s);
    sql(
      "INSERT INTO settings (key, value) VALUES "
      "('install_id', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), "
      "('onboarding_done', 'true'), ('theme', 'dark'), "
      "('text_size', 'large'), ('voice_speed', '1.0'), ('voice_name', '')",
    );
    sql(
      "INSERT INTO interests (title_id, kind, position, picked_at) VALUES "
      "('roman-history', 'topic_pick', 0, $opened)",
    );
    sql(
      "INSERT INTO study_list (title_id, added_at) VALUES "
      "('roman-history', $opened), ('chanakya', $done)",
    );
    sql(
      "INSERT INTO ratings (title_id, value, rated_at) VALUES "
      "('chanakya', -1, $done)",
    );
    sql(
      "INSERT INTO lesson_progress "
      "(lesson_id, title_id, lesson_index, last_opened_at, completed_at) "
      "VALUES ('roman-history.l01', 'roman-history', 1, $opened, $done), "
      "('roman-history.l02', 'roman-history', 2, $opened, NULL)",
    );
    sql(
      "INSERT INTO quiz_results (title_id, score, total, question_ids, "
      "wrong_ids, content_version, taken_at) VALUES "
      "('roman-history', 4, 6, '[\"roman-history.q001\"]', '[]', 3, $opened), "
      "('roman-history', 6, 6, '[]', '[]', 3, $done)",
    );
    sql(
      "INSERT INTO quiz_seen (question_id, title_id, seen_at) VALUES "
      "('roman-history.q001', 'roman-history', $opened)",
    );
    sql(
      "INSERT INTO feed_state "
      "(fact_id, title_id, saved, reaction, seen_at, updated_at) VALUES "
      "('roman-history.f001', 'roman-history', 1, -1, $opened, $done)",
    );
    sql(
      "INSERT INTO cached_docs (key, payload, etag, fetched_at) VALUES "
      "('catalogue', '{}', 'W/\"1\"', $opened)",
    );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    // Settings: values kept; only non-default values are dirty, stamped at
    // the epoch so the account's own values win; install_id never dirty.
    final settings = {
      for (final r in await db.select(db.settings).get()) r.key: r,
    };
    expect(settings['install_id']!.value, startsWith('aaaaaaaa'));
    expect(settings['install_id']!.dirty, isFalse);
    expect(settings['onboarding_done']!.value, 'true');
    expect(settings['onboarding_done']!.dirty, isTrue);
    expect(settings['text_size']!.dirty, isTrue);
    expect(settings['theme']!.dirty, isFalse);
    expect(settings['voice_name']!.dirty, isFalse);
    for (final r in settings.values) {
      expect(r.updatedAt, DateTime.utc(1970), reason: r.key);
      expect(r.deleted, isFalse);
    }

    final interest = (await db.select(db.interests).get()).single;
    expect(interest.titleId, 'roman-history');
    expect(interest.updatedAt, ms(opened));
    expect((interest.deleted, interest.dirty), (false, true));

    final study = await db.select(db.studyList).get();
    expect({for (final r in study) r.titleId: r.updatedAt}, {
      'roman-history': ms(opened),
      'chanakya': ms(done),
    });
    expect(study.every((r) => r.dirty && !r.deleted), isTrue);

    final rating = (await db.select(db.ratings).get()).single;
    expect((rating.value, rating.updatedAt, rating.dirty), (-1, ms(done), true));

    final progress = {
      for (final r in await db.select(db.lessonProgress).get()) r.lessonId: r,
    };
    // updated_at = the later of opened and completed.
    expect(progress['roman-history.l01']!.updatedAt, ms(done));
    expect(progress['roman-history.l01']!.completedAt, isNotNull);
    expect(progress['roman-history.l02']!.updatedAt, ms(opened));
    expect(progress['roman-history.l02']!.completedAt, isNull);

    final quiz = await (db.select(
      db.quizResults,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(quiz.map((r) => r.score), [4, 6]);
    expect(quiz.map((r) => r.id), [1, 2], reason: 'local ids unchanged');
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (final r in quiz) {
      expect(r.syncId, matches(uuid));
      expect(r.dirty, isTrue);
    }
    expect(quiz[0].syncId, isNot(quiz[1].syncId));
    expect(quiz[0].updatedAt, ms(opened));
    expect(quiz[0].questionIds, '["roman-history.q001"]');

    expect(await db.select(db.quizSeen).get(), hasLength(1));

    final feed = (await db.select(db.feedState).get()).single;
    expect((feed.saved, feed.reaction), (true, -1));
    expect(feed.updatedAt, ms(done), reason: 'seconds became milliseconds');
    expect(feed.dirty, isTrue);

    expect(await db.contentCacheDao.doc('catalogue'), isNotNull);
    expect(await db.select(db.syncState).get(), isEmpty);

    // Every migrated row is ready to push and serialises to a valid record.
    final records = await db.syncDao.dirtyRecords();
    expect(records.map((r) => r.kind).toSet(), {
      SyncKind.setting,
      SyncKind.interest,
      SyncKind.studyItem,
      SyncKind.rating,
      SyncKind.progress,
      SyncKind.quizResult,
      SyncKind.feedItem,
    });
    expect(
      records.where((r) => r.kind == SyncKind.setting).map((r) => r.id),
      unorderedEquals(['onboarding_done', 'text_size']),
    );
    await db.close();
  });
}
