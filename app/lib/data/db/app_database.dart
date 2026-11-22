// On-device database (CONTRACTS 5). All 5.1 tables exist from v1 so S7 (quiz)
// and S8 (feed) add no schema bump.
//
// Migrations (5.2): bump [schemaVersion] on every table change, then
//   dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/
// and add the step to `onUpgrade` with drift's generated `stepByStep`.
// Never edit a step that has shipped.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/content_cache_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/user_state_dao.dart';
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
  ],
  daos: [SettingsDao, UserStateDao, ContentCacheDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  /// The app database file (`maximus.sqlite` in app support storage).
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'maximus'));

  /// Injected in tests so ordering by time is deterministic.
  final DateTime Function() clock;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (_) => settingsDao.seedDefaults(),
  );

  /// "Clear my data" (CONTRACTS 5.1, D18): one transaction that empties
  /// every personal table and re-seeds settings with a new install id.
  /// The content cache stays.
  Future<void> clearMyData() => transaction(() async {
    for (final t in personalTables) {
      await delete(t).go();
    }
    await settingsDao.seedDefaults();
  });

  /// The tables "Clear my data" empties (5.1 column "Yes").
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
