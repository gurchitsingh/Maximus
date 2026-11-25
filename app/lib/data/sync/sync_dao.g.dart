// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $SettingsTable get settings => attachedDatabase.settings;
  $InterestsTable get interests => attachedDatabase.interests;
  $StudyListTable get studyList => attachedDatabase.studyList;
  $RatingsTable get ratings => attachedDatabase.ratings;
  $LessonProgressTable get lessonProgress => attachedDatabase.lessonProgress;
  $QuizResultsTable get quizResults => attachedDatabase.quizResults;
  $FeedStateTable get feedState => attachedDatabase.feedState;
  $SyncStateTable get syncState => attachedDatabase.syncState;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
  $$InterestsTableTableManager get interests =>
      $$InterestsTableTableManager(_db.attachedDatabase, _db.interests);
  $$StudyListTableTableManager get studyList =>
      $$StudyListTableTableManager(_db.attachedDatabase, _db.studyList);
  $$RatingsTableTableManager get ratings =>
      $$RatingsTableTableManager(_db.attachedDatabase, _db.ratings);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(
        _db.attachedDatabase,
        _db.lessonProgress,
      );
  $$QuizResultsTableTableManager get quizResults =>
      $$QuizResultsTableTableManager(_db.attachedDatabase, _db.quizResults);
  $$FeedStateTableTableManager get feedState =>
      $$FeedStateTableTableManager(_db.attachedDatabase, _db.feedState);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db.attachedDatabase, _db.syncState);
}
