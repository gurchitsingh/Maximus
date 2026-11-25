// Quiz state on the device (CONTRACTS 5.1, 7.1): `quiz_seen` and
// `quiz_results`. Uses the tables directly. Sync (S15, CONTRACTS 15.5):
// results get a UUID and are dirty until pushed; reads skip tombstones.
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/quiz/quiz_picker.dart';
import '../../domain/quiz/quiz_scoring.dart';
import '../db/app_database.dart';
import '../db/daos/settings_dao.dart' show newInstallId, stampAfter;
import '../models/title.dart';

class QuizRepository {
  QuizRepository(this.db);

  final AppDatabase db;

  /// Picks an attempt from the title's bank. In one transaction, so a new
  /// cycle's delete can never be lost or applied to a different pick.
  Future<List<QuizQuestion>> startAttempt(TitleDetail title, Random random) =>
      db.transaction(() async {
        final seen = await (db.select(
          db.quizSeen,
        )..where((t) => t.titleId.equals(title.id))).get();
        final pick = pickQuiz(
          bank: title.quiz.map((q) => q.id),
          seen: {for (final r in seen) r.questionId},
          random: random,
        );
        if (pick.newCycle) {
          await (db.delete(
            db.quizSeen,
          )..where((t) => t.titleId.equals(title.id))).go();
        }
        final byId = {for (final q in title.quiz) q.id: q};
        return [for (final id in pick.ids) byId[id]!];
      });

  /// Answering a question marks it seen, even if the attempt is abandoned.
  Future<void> markSeen(QuizQuestion q) => db
      .into(db.quizSeen)
      .insert(
        QuizSeenCompanion.insert(
          questionId: q.id,
          titleId: q.titleId,
          seenAt: db.clock(),
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// "See result": one row per finished attempt. Returns its id.
  Future<int> saveResult({
    required String titleId,
    required QuizAttempt attempt,
    required int contentVersion,
  }) => db
      .into(db.quizResults)
      .insert(
        QuizResultsCompanion.insert(
          titleId: titleId,
          score: attempt.score,
          total: attempt.total,
          questionIds: jsonEncode(attempt.questionIds),
          wrongIds: jsonEncode(attempt.wrongIds),
          contentVersion: contentVersion,
          takenAt: db.clock(),
          syncId: Value(newInstallId()),
          updatedAt: Value(stampAfter(db.clock(), null)),
        ),
      );

  /// The attempt [id] of this title, or its latest when [id] is null or
  /// unknown.
  Future<QuizResultRow?> result(String titleId, int? id) async {
    if (id != null) {
      final row =
          await (db.select(db.quizResults)
                ..where(
                  (t) =>
                      t.id.equals(id) &
                      t.titleId.equals(titleId) &
                      t.deleted.not(),
                ))
              .getSingleOrNull();
      if (row != null) return row;
    }
    return (db.select(db.quizResults)
          ..where((t) => t.titleId.equals(titleId) & t.deleted.not())
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<List<QuizResultRow>> watchResults() =>
      (db.select(db.quizResults)..where((t) => t.deleted.not())).watch();
}

extension QuizResultIds on QuizResultRow {
  List<String> get shownIds => _ids(questionIds);
  List<String> get missedIds => _ids(wrongIds);

  static List<String> _ids(String json) =>
      (jsonDecode(json) as List<dynamic>).cast<String>();
}
