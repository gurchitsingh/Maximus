import 'package:drift/drift.dart';

import '../app_database.dart';

part 'user_state_dao.g.dart';

/// Study list, ratings, lesson progress, interests and the feed reactions
/// match % reads (CONTRACTS 5.1, 6.1).
@DriftAccessor(
  tables: [StudyList, Ratings, LessonProgress, Interests, FeedState],
)
class UserStateDao extends DatabaseAccessor<AppDatabase>
    with _$UserStateDaoMixin {
  UserStateDao(super.db);

  DateTime get _now => db.clock();

  // ---- study list (newest first) ----

  Stream<List<StudyItemRow>> watchStudyList() =>
      (select(studyList)..orderBy([
            (t) => OrderingTerm.desc(t.addedAt),
            (t) => OrderingTerm.desc(t.rowId),
          ]))
          .watch();

  Future<void> addToStudyList(String titleId) => into(studyList).insert(
    StudyListCompanion.insert(titleId: titleId, addedAt: _now),
    mode: InsertMode.insertOrIgnore,
  );

  Future<void> removeFromStudyList(String titleId) =>
      (delete(studyList)..where((t) => t.titleId.equals(titleId))).go();

  // ---- ratings ----

  Stream<List<RatingRow>> watchRatings() =>
      (select(ratings)..orderBy([
            (t) => OrderingTerm.desc(t.ratedAt),
            (t) => OrderingTerm.desc(t.rowId),
          ]))
          .watch();

  /// [value] -1, 0 or 1; null deletes the row (re-tap of the chosen thumb).
  Future<void> setRating(String titleId, int? value) async {
    if (value == null) {
      await (delete(ratings)..where((t) => t.titleId.equals(titleId))).go();
      return;
    }
    assert(value >= -1 && value <= 1);
    // Delete then insert so the newest rating also has the newest rowid
    // ("most recent rating up" in CONTRACTS 6.3 ties on equal seconds).
    await transaction(() async {
      await (delete(ratings)..where((t) => t.titleId.equals(titleId))).go();
      await into(ratings).insert(
        RatingsCompanion.insert(titleId: titleId, value: value, ratedAt: _now),
      );
    });
  }

  // ---- lesson progress ----

  Stream<List<LessonProgressRow>> watchProgress() =>
      (select(lessonProgress)..orderBy([
            (t) => OrderingTerm.desc(t.lastOpenedAt),
            (t) => OrderingTerm.desc(t.lessonIndex),
          ]))
          .watch();

  /// Marks a lesson opened now; keeps its completed_at.
  Future<void> openLesson({
    required String titleId,
    required String lessonId,
    required int lessonIndex,
  }) => into(lessonProgress).insert(
    LessonProgressCompanion.insert(
      lessonId: lessonId,
      titleId: titleId,
      lessonIndex: lessonIndex,
      lastOpenedAt: _now,
    ),
    onConflict: DoUpdate(
      (_) => LessonProgressCompanion(
        lastOpenedAt: Value(_now),
        lessonIndex: Value(lessonIndex),
      ),
    ),
  );

  /// Next or Finish tapped on this lesson. The first completion time stays.
  Future<void> completeLesson({
    required String titleId,
    required String lessonId,
    required int lessonIndex,
  }) => transaction(() async {
    await openLesson(
      titleId: titleId,
      lessonId: lessonId,
      lessonIndex: lessonIndex,
    );
    await (update(lessonProgress)
          ..where((t) => t.lessonId.equals(lessonId) & t.completedAt.isNull()))
        .write(LessonProgressCompanion(completedAt: Value(_now)));
  });

  /// Completed lesson ids of a title, read now (not from a paused stream).
  Future<Set<String>> completedLessonIds(String titleId) async {
    final rows =
        await (select(lessonProgress)..where(
              (t) => t.titleId.equals(titleId) & t.completedAt.isNotNull(),
            ))
            .get();
    return {for (final r in rows) r.lessonId};
  }

  // ---- read-only for match % (written by S5 and S8) ----

  Stream<List<InterestRow>> watchInterests() => (select(
    interests,
  )..orderBy([(t) => OrderingTerm.asc(t.position)])).watch();

  Stream<List<FeedStateRow>> watchFeedState() => select(feedState).watch();
}
