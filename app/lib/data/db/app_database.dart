// On-device database (CONTRACTS 5). All 5.1 tables exist from v1 so S7 (quiz)
// and S8 (feed) add no schema bump.
//
// Migrations (5.2): bump [schemaVersion] on every table change, then
//   dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/
//   dart run drift_dev schema steps drift_schemas/ lib/data/db/schema_versions.dart
//   dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
// and add the step to `onUpgrade`. Never edit a step that has shipped.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../sync/sync_dao.dart';
import 'daos/content_cache_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/user_state_dao.dart';
import 'schema_versions.dart';
import 'tables/cache_tables.dart';
import 'tables/user_tables.dart';

export 'tables/cache_tables.dart';
export 'tables/user_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Settings,
    Interests,
    StudyList,
    Ratings,
    LessonProgress,
    QuizResults,
    QuizSeen,
    FeedState,
    CachedDocs,
    CachedTitles,
    SyncState,
  ],
  daos: [SettingsDao, UserStateDao, ContentCacheDao, SyncDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  /// The app database file (`maximus.sqlite` in app support storage).
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'maximus'));

  /// Injected in tests so ordering by time is deterministic.
  final DateTime Function() clock;

  /// v2 (S15): sync columns on every synced table, quiz_results.sync_id,
  /// feed_state.updated_at in milliseconds, the sync_state table.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      await transaction(() => _steps(m, from, to));
    },
    beforeOpen: (_) => settingsDao.seedDefaults(),
  );

  static final _steps = stepByStep(from1To2: migrateV1ToV2);

  /// "Clear my data" (CONTRACTS 15.5, D38): tombstones every synced row so
  /// the account and other devices clear too, empties quiz_seen, resets the
  /// synced settings to their defaults (as changes, so they sync) and makes
  /// a new install id. The content cache stays.
  Future<void> clearMyData() => transaction(() async {
    await syncDao.tombstoneAll();
    await delete(quizSeen).go();
    await settingsDao.resetToDefaults();
  });

  /// Sign-out and account deletion (14.5, 15.5, 17): physically removes
  /// every personal row and the sync state, with no tombstones (the data
  /// stays on the server), then re-seeds clean default settings. The
  /// content cache stays.
  Future<void> wipeUserData() => transaction(() async {
    for (final t in personalTables) {
      await delete(t).go();
    }
    await delete(syncState).go();
    await settingsDao.seedDefaults();
  });

  /// The tables "Clear my data" and sign-out empty (5.1 column "Yes").
  List<TableInfo<Table, Object?>> get personalTables => [
    settings,
    interests,
    studyList,
    ratings,
    lessonProgress,
    quizResults,
    quizSeen,
    feedState,
  ];
}

/// v1 to v2 (S15). Existing rows keep their data, get `updated_at` from
/// their own time column (seconds to milliseconds) and `dirty = true`, so
/// the first sign-in uploads them (15.5). Settings are the exception: a
/// value that differs from the default is dirty with `updated_at` = the
/// epoch, so it fills an empty account but never beats a value the account
/// already has; defaults stay clean.
Future<void> migrateV1ToV2(Migrator m, Schema2 s) async {
  Expression<int> ms(String sql) => CustomExpression<int>('($sql) * 1000');

  await m.alterTable(
    TableMigration(
      s.settings,
      newColumns: [s.settings.updatedAt, s.settings.deleted, s.settings.dirty],
      columnTransformer: {
        s.settings.dirty: const CustomExpression<bool>(
          "CASE key "
          "WHEN 'onboarding_done' THEN value <> 'false' "
          "WHEN 'theme' THEN value <> 'dark' "
          "WHEN 'text_size' THEN value <> 'medium' "
          "WHEN 'voice_speed' THEN value <> '1.0' "
          "WHEN 'voice_name' THEN value <> '' "
          "ELSE 0 END",
        ),
      },
    ),
  );
  await m.alterTable(
    TableMigration(
      s.interests,
      newColumns: [s.interests.updatedAt, s.interests.deleted, s.interests.dirty],
      columnTransformer: {s.interests.updatedAt: ms('picked_at')},
    ),
  );
  await m.alterTable(
    TableMigration(
      s.studyList,
      newColumns: [s.studyList.updatedAt, s.studyList.deleted, s.studyList.dirty],
      columnTransformer: {s.studyList.updatedAt: ms('added_at')},
    ),
  );
  await m.alterTable(
    TableMigration(
      s.ratings,
      newColumns: [s.ratings.updatedAt, s.ratings.deleted, s.ratings.dirty],
      columnTransformer: {s.ratings.updatedAt: ms('rated_at')},
    ),
  );
  await m.alterTable(
    TableMigration(
      s.lessonProgress,
      newColumns: [
        s.lessonProgress.updatedAt,
        s.lessonProgress.deleted,
        s.lessonProgress.dirty,
      ],
      columnTransformer: {
        s.lessonProgress.updatedAt: ms(
          'max(last_opened_at, coalesce(completed_at, 0))',
        ),
      },
    ),
  );
  await m.alterTable(
    TableMigration(
      s.quizResults,
      newColumns: [
        s.quizResults.syncId,
        s.quizResults.updatedAt,
        s.quizResults.deleted,
        s.quizResults.dirty,
      ],
      columnTransformer: {
        // A UUID v4 per existing attempt (version nibble 4, variant 8..b).
        s.quizResults.syncId: const CustomExpression<String>(
          "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || "
          "'-4' || substr(lower(hex(randomblob(2))), 2) || '-' || "
          "substr('89ab', 1 + (abs(random()) % 4), 1) || "
          "substr(lower(hex(randomblob(2))), 2) || '-' || "
          "lower(hex(randomblob(6)))",
        ),
        s.quizResults.updatedAt: ms('taken_at'),
      },
    ),
  );
  await m.alterTable(
    TableMigration(
      s.feedState,
      newColumns: [s.feedState.deleted, s.feedState.dirty],
      columnTransformer: {s.feedState.updatedAt: ms('updated_at')},
    ),
  );
  await m.createTable(s.syncState);
}
