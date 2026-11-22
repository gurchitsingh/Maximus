// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_state_dao.dart';

// ignore_for_file: type=lint
mixin _$UserStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $StudyListTable get studyList => attachedDatabase.studyList;
  $RatingsTable get ratings => attachedDatabase.ratings;
  $LessonProgressTable get lessonProgress => attachedDatabase.lessonProgress;
  $InterestsTable get interests => attachedDatabase.interests;
  $FeedStateTable get feedState => attachedDatabase.feedState;
  UserStateDaoManager get managers => UserStateDaoManager(this);
}

class UserStateDaoManager {
  final _$UserStateDaoMixin _db;
  UserStateDaoManager(this._db);
  $$StudyListTableTableManager get studyList =>
      $$StudyListTableTableManager(_db.attachedDatabase, _db.studyList);
  $$RatingsTableTableManager get ratings =>
      $$RatingsTableTableManager(_db.attachedDatabase, _db.ratings);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(
        _db.attachedDatabase,
        _db.lessonProgress,
      );
  $$InterestsTableTableManager get interests =>
      $$InterestsTableTableManager(_db.attachedDatabase, _db.interests);
  $$FeedStateTableTableManager get feedState =>
      $$FeedStateTableTableManager(_db.attachedDatabase, _db.feedState);
}
