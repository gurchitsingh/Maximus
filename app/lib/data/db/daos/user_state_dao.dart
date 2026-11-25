import 'package:drift/drift.dart';

import '../app_database.dart';
import 'settings_dao.dart' show stampAfter;

part 'user_state_dao.g.dart';

/// Study list, ratings, lesson progress, interests and the feed reactions
/// match % reads (CONTRACTS 5.1, 6.1).
///
/// Sync (15.5): every read skips tombstones (`deleted`); every write sets
/// `updated_at` to now (never before the row's previous stamp) and
/// `dirty`; a delete is a dirty tombstone until the server has it.
@DriftAccessor(
  tables: [StudyList, Ratings, LessonProgress, Interests, FeedState],
)
class UserStateDao extends DatabaseAccessor<AppDatabase>
    with _$UserStateDaoMixin {
  UserStateDao(super.db);

  DateTime get _now => db.clock();

  DateTime _stamp(DateTime? previous) => stampAfter(_now, previous);

  // ---- study list (newest first) ----

  Stream<List<StudyItemRow>> watchStudyList() =>
      (select(studyList)
            ..where((t) => t.deleted.not())
            ..orderBy([
              (t) => OrderingTerm.desc(t.addedAt),
              (t) => OrderingTerm.desc(t.rowId),
            ]))
          .watch();

  Future<void> addToStudyList(String titleId) => transaction(() async {
    final old = await (select(
      studyList,
    )..where((t) => t.titleId.equals(titleId))).getSingleOrNull();
    if (old != null && !old.deleted) return;
    await into(studyList).insertOnConflictUpdate(
      StudyListCompanion.insert(
        titleId: titleId,
        addedAt: _now,
        updatedAt: Value(_stamp(old?.updatedAt)),
        deleted: const Value(false),
        dirty: const Value(true),
      ),
    );
  });

  Future<void> removeFromStudyList(String titleId) => transaction(() async {
    final old = await (select(
      studyList,
    )..where((t) => t.titleId.equals(titleId))).getSingleOrNull();
    if (old == null || old.deleted) return;
    await (update(studyList)..where((t) => t.titleId.equals(titleId))).write(
      StudyListCompanion(
        updatedAt: Value(_stamp(old.updatedAt)),
        deleted: const Value(true),
        dirty: const Value(true),
      ),
    );
  });

  // ---- ratings ----

  Stream<List<RatingRow>> watchRatings() =>
      (select(ratings)
            ..where((t) => t.deleted.not())
            ..orderBy([
              (t) => OrderingTerm.desc(t.ratedAt),
              (t) => OrderingTerm.desc(t.rowId),
            ]))
          .watch();

  /// [value] -1, 0 or 1; null removes the rating (re-tap of the chosen
  /// thumb) as a tombstone.
  Future<void> setRating(String titleId, int? value) => transaction(() async {
    final old = await (select(
      ratings,
    )..where((t) => t.titleId.equals(titleId))).getSingleOrNull();
    if (value == null) {
      if (old == null || old.deleted) return;
      await (update(ratings)..where((t) => t.titleId.equals(titleId))).write(
        RatingsCompanion(
          updatedAt: Value(_stamp(old.updatedAt)),
          deleted: const Value(true),
          dirty: const Value(true),
        ),
      );
      return;
    }
    assert(value >= -1 && value <= 1);
    // Delete then insert so the newest rating also has the newest rowid
    // ("most recent rating up" in CONTRACTS 6.3 ties on equal seconds).
    await (delete(ratings)..where((t) => t.titleId.equals(titleId))).go();
    await into(ratings).insert(
      RatingsCompanion.insert(
        titleId: titleId,
        value: value,
        ratedAt: _now,
        updatedAt: Value(_stamp(old?.updatedAt)),
        deleted: const Value(false),
        dirty: const Value(true),
      ),
    );
  });

  // ---- lesson progress ----

  Stream<List<LessonProgressRow>> watchProgress() =>
      (select(lessonProgress)
            ..where((t) => t.deleted.not())
            ..orderBy([
              (t) => OrderingTerm.desc(t.lastOpenedAt),
              (t) => OrderingTerm.desc(t.lessonIndex),
            ]))
          .watch();

  Future<LessonProgressRow?> _progressRow(String lessonId) => (select(
    lessonProgress,
  )..where((t) => t.lessonId.equals(lessonId))).getSingleOrNull();

  /// Marks a lesson opened now; keeps its completed_at (a tombstoned row
  /// starts fresh).
  Future<void> openLesson({
    required String titleId,
    required String lessonId,
    required int lessonIndex,
  }) => transaction(() async {
    final old = await _progressRow(lessonId);
    await into(lessonProgress).insertOnConflictUpdate(
      LessonProgressCompanion.insert(
        lessonId: lessonId,
        titleId: titleId,
        lessonIndex: lessonIndex,
        lastOpenedAt: _now,
        completedAt: Value(old == null || old.deleted ? null : old.completedAt),
        updatedAt: Value(_stamp(old?.updatedAt)),
        deleted: const Value(false),
        dirty: const Value(true),
      ),
    );
  });

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
    final row = (await _progressRow(lessonId))!;
    if (row.completedAt != null) return;
    await (update(
      lessonProgress,
    )..where((t) => t.lessonId.equals(lessonId))).write(
      LessonProgressCompanion(
        completedAt: Value(_now),
        updatedAt: Value(_stamp(row.updatedAt)),
        dirty: const Value(true),
      ),
    );
  });

  /// Completed lesson ids of a title, read now (not from a paused stream).
  Future<Set<String>> completedLessonIds(String titleId) async {
    final rows =
        await (select(lessonProgress)..where(
              (t) =>
                  t.titleId.equals(titleId) &
                  t.completedAt.isNotNull() &
                  t.deleted.not(),
            ))
            .get();
    return {for (final r in rows) r.lessonId};
  }

  // ---- interests (onboarding picks, written by S5) ----

  Stream<List<InterestRow>> watchInterests() =>
      (select(interests)
            ..where((t) => t.deleted.not())
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  /// Replaces the picks of one [kind] (`topic_pick` | `leader_pick`) with
  /// [titleIds] in order: kept and new picks are written, dropped ones
  /// become tombstones, so every device ends with the same picks.
  Future<void> setInterests(String kind, List<String> titleIds) =>
      transaction(() async {
        final old = {
          for (final r in await (select(
            interests,
          )..where((t) => t.kind.equals(kind))).get())
            r.titleId: r,
        };
        for (final (i, id) in titleIds.indexed) {
          final o = old[id];
          if (o != null && !o.deleted && o.position == i) continue;
          await into(interests).insertOnConflictUpdate(
            InterestsCompanion.insert(
              titleId: id,
              kind: kind,
              position: i,
              pickedAt: o == null || o.deleted ? _now : o.pickedAt,
              updatedAt: Value(_stamp(o?.updatedAt)),
              deleted: const Value(false),
              dirty: const Value(true),
            ),
          );
        }
        for (final o in old.values) {
          if (o.deleted || titleIds.contains(o.titleId)) continue;
          await (update(interests)..where(
                (t) => t.kind.equals(kind) & t.titleId.equals(o.titleId),
              ))
              .write(
                InterestsCompanion(
                  updatedAt: Value(_stamp(o.updatedAt)),
                  deleted: const Value(true),
                  dirty: const Value(true),
                ),
              );
        }
      });

  Stream<List<FeedStateRow>> watchFeedState() =>
      (select(feedState)..where((t) => t.deleted.not())).watch();

  // ---- feed reactions (S8, CONTRACTS 7.2) ----

  Future<FeedStateRow?> _feedRow(String factId) async {
    final r = await (select(
      feedState,
    )..where((t) => t.factId.equals(factId))).getSingleOrNull();
    return r;
  }

  Future<void> _putFeedRow({
    required FeedStateRow? old,
    required String factId,
    required String titleId,
    required bool saved,
    required int reaction,
    required DateTime? seenAt,
  }) => into(feedState).insertOnConflictUpdate(
    FeedStateCompanion.insert(
      factId: factId,
      titleId: titleId,
      saved: Value(saved),
      reaction: Value(reaction),
      seenAt: Value(seenAt),
      updatedAt: _stamp(old?.updatedAt),
      deleted: const Value(false),
      dirty: const Value(true),
    ),
  );

  /// A tombstoned row reads as no row.
  FeedStateRow? _live(FeedStateRow? r) => r == null || r.deleted ? null : r;

  /// Save button: flips `saved`, keeps the reaction and seen mark.
  Future<void> toggleFactSaved({
    required String factId,
    required String titleId,
  }) => transaction(() async {
    final old = await _feedRow(factId);
    final row = _live(old);
    await _putFeedRow(
      old: old,
      factId: factId,
      titleId: titleId,
      saved: !(row?.saved ?? false),
      reaction: row?.reaction ?? 0,
      seenAt: row?.seenAt,
    );
  });

  /// Like ([value] 1) or Dislike (-1): they replace each other, and tapping
  /// the active one again sets 0. Returns the new reaction.
  Future<int> toggleFactReaction({
    required String factId,
    required String titleId,
    required int value,
  }) {
    assert(value == 1 || value == -1);
    return transaction(() async {
      final old = await _feedRow(factId);
      final row = _live(old);
      final next = row?.reaction == value ? 0 : value;
      await _putFeedRow(
        old: old,
        factId: factId,
        titleId: titleId,
        saved: row?.saved ?? false,
        reaction: next,
        seenAt: row?.seenAt,
      );
      return next;
    });
  }

  /// The card has been on screen for 1 s.
  Future<void> markFactSeen({
    required String factId,
    required String titleId,
  }) => transaction(() async {
    final old = await _feedRow(factId);
    final row = _live(old);
    await _putFeedRow(
      old: old,
      factId: factId,
      titleId: titleId,
      saved: row?.saved ?? false,
      reaction: row?.reaction ?? 0,
      seenAt: _now,
    );
  });
}
