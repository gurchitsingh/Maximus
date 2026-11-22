// Personal tables (CONTRACTS 5.1). Every one is emptied by "Clear my data".
// SQL names are the snake_case of the class names (study_list, quiz_seen...).
import 'package:drift/drift.dart';

/// Key-value device settings. Keys and defaults: [SettingKeys].
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Onboarding picks (S5 writes them): 3 to 5 topics, 0 to 3 leaders.
@DataClassName('InterestRow')
class Interests extends Table {
  TextColumn get titleId => text()();

  /// `topic_pick` | `leader_pick`.
  TextColumn get kind => text()();
  IntColumn get position => integer()();
  DateTimeColumn get pickedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {titleId, kind};
}

@DataClassName('StudyItemRow')
class StudyList extends Table {
  TextColumn get titleId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {titleId};
}

/// One per title; re-tapping the chosen thumb deletes the row.
@DataClassName('RatingRow')
class Ratings extends Table {
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
class LessonProgress extends Table {
  TextColumn get lessonId => text()();
  TextColumn get titleId => text()();
  IntColumn get lessonIndex => integer()();
  DateTimeColumn get lastOpenedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {lessonId};
}

/// One row per finished quiz attempt (S7).
@DataClassName('QuizResultRow')
class QuizResults extends Table {
  IntColumn get id => integer().autoIncrement()();
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

/// Answered questions in the current quiz cycle (S7, CONTRACTS 7.1).
@DataClassName('QuizSeenRow')
@TableIndex(name: 'quiz_seen_title', columns: {#titleId})
class QuizSeen extends Table {
  TextColumn get questionId => text()();
  TextColumn get titleId => text()();
  DateTimeColumn get seenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {questionId};
}

/// Feed saves and reactions per fact (S8, CONTRACTS 7.2).
@DataClassName('FeedStateRow')
@TableIndex(name: 'feed_state_title', columns: {#titleId})
class FeedState extends Table {
  TextColumn get factId => text()();
  TextColumn get titleId => text()();
  BoolColumn get saved => boolean().withDefault(const Constant(false))();

  /// -1, 0, 1.
  IntColumn get reaction => integer().withDefault(const Constant(0))();
  DateTimeColumn get seenAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {factId};
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
}
