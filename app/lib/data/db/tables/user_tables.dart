// Personal tables (CONTRACTS 5.1). Every one is emptied by "Clear my data".
// SQL names are the snake_case of the class names (study_list, quiz_seen...).
//
// Schema v2 (S15, CONTRACTS 15.5): every synced table carries [SyncColumns]:
// `updated_at` (UTC, milliseconds), `deleted` (tombstone) and `dirty` (not
// yet acknowledged by the server). quiz_seen does not sync.
import 'package:drift/drift.dart';

import '../daos/settings_dao.dart' show newInstallId;

/// Stores a UTC [DateTime] as integer milliseconds since the epoch. The
/// server keeps milliseconds too, so two edits in the same second still
/// order correctly (drift's default DateTime storage is whole seconds).
class EpochMs extends TypeConverter<DateTime, int> {
  const EpochMs();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

/// The three sync columns of CONTRACTS 15.5.
mixin SyncColumns on Table {
  /// When the user made the change (device clock, UTC). Decides conflicts.
  /// The DAOs always set it; the client default is only a fallback.
  IntColumn get updatedAt => integer()
      .clientDefault(() => DateTime.now().millisecondsSinceEpoch)
      .map(const EpochMs())();

  /// Tombstone: hidden from every read, removed once the server has it.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Changed here and not yet acknowledged by the server.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

/// Key-value device settings. Keys and defaults: [SettingKeys].
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  /// Seeded defaults are 0 (the epoch) and clean, so any value the account
  /// already has wins over them on the first pull.
  IntColumn get updatedAt =>
      integer().map(const EpochMs()).withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {key};
}

/// Onboarding picks (S5 writes them): 3 to 5 topics, 0 to 3 leaders.
@DataClassName('InterestRow')
class Interests extends Table with SyncColumns {
  TextColumn get titleId => text()();

  /// `topic_pick` | `leader_pick`.
  TextColumn get kind => text()();
  IntColumn get position => integer()();
  DateTimeColumn get pickedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {titleId, kind};
}

@DataClassName('StudyItemRow')
class StudyList extends Table with SyncColumns {
  TextColumn get titleId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {titleId};
}

/// One per title; re-tapping the chosen thumb tombstones the row.
@DataClassName('RatingRow')
class Ratings extends Table with SyncColumns {
  TextColumn get titleId => text()();

  /// -1, 0, 1.
  IntColumn get value => integer()();
  DateTimeColumn get ratedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {titleId};
}

/// Completed = the user tapped Next or Finish on it. Resume = newest
/// `last_opened_at`.
@DataClassName('LessonProgressRow')
@TableIndex(name: 'lesson_progress_title', columns: {#titleId})
class LessonProgress extends Table with SyncColumns {
  TextColumn get lessonId => text()();
  TextColumn get titleId => text()();
  IntColumn get lessonIndex => integer()();
  DateTimeColumn get lastOpenedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {lessonId};
}

/// One row per finished quiz attempt (S7). Append-only: never edited, only
/// tombstoned (CONTRACTS 15.1).
@DataClassName('QuizResultRow')
class QuizResults extends Table with SyncColumns {
  /// Local id, used by the result route (`?attempt=`). Not synced.
  IntColumn get id => integer().autoIncrement()();

  /// The record id on the server: a UUID v4 made on the device.
  TextColumn get syncId => text().clientDefault(newInstallId).unique()();
  TextColumn get titleId => text()();
  IntColumn get score => integer()();
  IntColumn get total => integer()();

  /// JSON list of question ids in shown order.
  TextColumn get questionIds => text()();

  /// JSON list of the missed question ids.
  TextColumn get wrongIds => text()();
  IntColumn get contentVersion => integer()();
  DateTimeColumn get takenAt => dateTime()();
}

/// Answered questions in the current quiz cycle (S7, CONTRACTS 7.1). Per
/// device: not synced.
@DataClassName('QuizSeenRow')
@TableIndex(name: 'quiz_seen_title', columns: {#titleId})
class QuizSeen extends Table {
  TextColumn get questionId => text()();
  TextColumn get titleId => text()();
  DateTimeColumn get seenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {questionId};
}

/// Feed saves and reactions per fact (S8, CONTRACTS 7.2). `updated_at`
/// existed in v1 (seconds); v2 stores it in milliseconds like the others.
@DataClassName('FeedStateRow')
@TableIndex(name: 'feed_state_title', columns: {#titleId})
class FeedState extends Table with SyncColumns {
  /// Required here (it was in v1), unlike the other tables' fallback.
  @override
  IntColumn get updatedAt => integer().map(const EpochMs())();

  TextColumn get factId => text()();
  TextColumn get titleId => text()();
  BoolColumn get saved => boolean().withDefault(const Constant(false))();

  /// -1, 0, 1.
  IntColumn get reaction => integer().withDefault(const Constant(0))();
  DateTimeColumn get seenAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {factId};
}

/// Sync bookkeeping (CONTRACTS 15.5): `cursor`, `last_sync_at`, `user_id`.
/// Wiped on sign-out; not personal content.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Setting keys and their defaults (CONTRACTS 5.1).
abstract final class SettingKeys {
  static const installId = 'install_id';
  static const onboardingDone = 'onboarding_done';
  static const theme = 'theme';
  static const textSize = 'text_size';
  static const voiceSpeed = 'voice_speed';
  static const voiceName = 'voice_name';

  /// install_id is generated, so it is not in this map.
  static const defaults = {
    onboardingDone: 'false',
    theme: 'dark',
    textSize: 'medium',
    voiceSpeed: '1.0',
    voiceName: '',
  };

  /// The keys that sync (15.1). **Never** install_id.
  static const synced = {
    onboardingDone,
    theme,
    textSize,
    voiceSpeed,
    voiceName,
  };
}
