// Study list, ratings and lesson progress (CONTRACTS 5.1 "user_state").
import '../db/app_database.dart';
import '../models/title.dart';

class UserStateRepository {
  UserStateRepository(this.db);

  final AppDatabase db;

  Future<void> setOnStudyList(String titleId, bool on) => on
      ? db.userStateDao.addToStudyList(titleId)
      : db.userStateDao.removeFromStudyList(titleId);

  Future<void> setRating(String titleId, int? value) =>
      db.userStateDao.setRating(titleId, value);

  Future<void> openLesson(Lesson l) => db.userStateDao.openLesson(
    titleId: l.titleId,
    lessonId: l.id,
    lessonIndex: l.index,
  );

  Future<void> completeLesson(Lesson l) => db.userStateDao.completeLesson(
    titleId: l.titleId,
    lessonId: l.id,
    lessonIndex: l.index,
  );
}

/// Reading progress of one title, from its `lesson_progress` rows.
class TitleProgress {
  TitleProgress({
    required this.titleId,
    required this.lessonCount,
    required List<LessonProgressRow> rows,
  }) : rows = [
         for (final r in rows)
           if (r.titleId == titleId) r,
       ];

  final String titleId;

  /// Catalogue `lesson_count` (served lessons).
  final int lessonCount;

  /// This title's rows, newest opened first (DAO order).
  final List<LessonProgressRow> rows;

  bool get started => rows.isNotEmpty;

  /// Completed lessons that still exist (index within 1..lessonCount).
  int get completed => rows
      .where(
        (r) =>
            r.completedAt != null &&
            r.lessonIndex >= 1 &&
            r.lessonIndex <= lessonCount,
      )
      .length;

  double get fraction =>
      lessonCount == 0 ? 0 : (completed / lessonCount).clamp(0.0, 1.0);

  bool get finished => lessonCount > 0 && completed >= lessonCount;

  /// Index of the lesson to resume ("Lesson 4 of 8"), null if not started.
  int? get resumeIndex {
    if (rows.isEmpty) return null;
    final last = rows.first;
    final top = lessonCount < 1 ? 1 : lessonCount;
    if (last.completedAt == null) return last.lessonIndex.clamp(1, top);
    // Last opened is done: the next unread lesson after it, wrapping to the
    // first unread one; when all are read, stay on the last opened.
    final done = {
      for (final r in rows)
        if (r.completedAt != null) r.lessonIndex,
    };
    for (var i = last.lessonIndex + 1; i <= lessonCount; i++) {
      if (!done.contains(i)) return i;
    }
    for (var i = 1; i < last.lessonIndex && i <= lessonCount; i++) {
      if (!done.contains(i)) return i;
    }
    return last.lessonIndex.clamp(1, top);
  }

  /// "Lesson 4 of 8" or "Not started".
  String get label => resumeIndex == null
      ? 'Not started'
      : 'Lesson $resumeIndex of $lessonCount';

  /// The lesson Start, Continue, Resume and Study rows open (FLOW 5: the
  /// next unfinished lesson after the last one opened; lesson 1 if none).
  Lesson resumeLesson(List<Lesson> lessons) {
    assert(lessons.isNotEmpty);
    final i = resumeIndex;
    if (i == null) return lessons.first;
    return lessons.firstWhere((l) => l.index == i, orElse: () => lessons.first);
  }
}
