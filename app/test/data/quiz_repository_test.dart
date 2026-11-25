// quiz_seen and quiz_results behaviour on an in-memory database (CONTRACTS
// 7.1), using the bundled Roman history bank of 10 questions.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/models/title.dart';
import 'package:maximus/data/repositories/quiz_repository.dart';
import 'package:maximus/domain/quiz/quiz_scoring.dart';

void main() {
  late AppDatabase db;
  late QuizRepository repo;
  late TitleDetail roman;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    repo = QuizRepository(db);
    roman = TitleDetail.fromJson(
      jsonDecode(File('assets/dev/roman-history.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });
  tearDown(() => db.close());

  Future<Set<String>> seenIds() async => {
    for (final r in await db.select(db.quizSeen).get()) r.questionId,
  };

  QuizAttempt attemptOf(List<QuizQuestion> qs) => QuizAttempt(
    questionIds: [for (final q in qs) q.id],
    correctIndexes: [for (final q in qs) q.correctIndex],
  );

  test('the bundled bank can run a quiz', () {
    expect(roman.quiz.length, greaterThanOrEqualTo(6));
    for (final q in roman.quiz) {
      expect(q.options, hasLength(4));
      expect(q.correctIndex, inInclusiveRange(0, 3));
    }
  });

  test('second attempt avoids answered questions, then a new cycle', () async {
    final random = Random(4);
    final first = await repo.startAttempt(roman, random);
    expect(first, hasLength(6));
    for (final q in first) {
      await repo.markSeen(q);
    }
    expect(await seenIds(), {for (final q in first) q.id});

    // 4 of 10 are unseen: all 4 are picked and the old cycle is cleared.
    final second = await repo.startAttempt(roman, random);
    final unseen = roman.quiz
        .map((q) => q.id)
        .where((id) => !first.any((q) => q.id == id))
        .toSet();
    expect(second.take(4).map((q) => q.id).toSet(), unseen);
    expect(second.map((q) => q.id).toSet(), hasLength(6));
    expect(await seenIds(), isEmpty);
  });

  test('an abandoned attempt keeps seen rows and stores no result', () async {
    final qs = await repo.startAttempt(roman, Random(1));
    await repo.markSeen(qs.first);
    expect(await seenIds(), {qs.first.id});
    expect(await db.select(db.quizResults).get(), isEmpty);
  });

  test('a new cycle only clears this title', () async {
    await db
        .into(db.quizSeen)
        .insert(
          QuizSeenCompanion.insert(
            questionId: 'other.q001',
            titleId: 'other',
            seenAt: DateTime(2026),
          ),
        );
    for (final q in roman.quiz) {
      await repo.markSeen(q);
    }
    await repo.startAttempt(roman, Random(2));
    expect(await seenIds(), {'other.q001'});
  });

  test('saveResult stores score, order and missed ids', () async {
    final qs = await repo.startAttempt(roman, Random(3));
    final a = attemptOf(qs);
    for (var i = 0; i < qs.length; i++) {
      a.answer(i, i < 4 ? qs[i].correctIndex : (qs[i].correctIndex + 1) % 4);
    }
    final id = await repo.saveResult(
      titleId: roman.id,
      attempt: a,
      contentVersion: roman.summary.contentVersion,
    );
    final row = (await repo.result(roman.id, id))!;
    expect(row.score, 4);
    expect(row.total, 6);
    expect(row.shownIds, [for (final q in qs) q.id]);
    expect(row.missedIds, [qs[4].id, qs[5].id]);
    expect(row.contentVersion, roman.summary.contentVersion);
  });

  test('result falls back to the latest attempt of the title', () async {
    final a = attemptOf(await repo.startAttempt(roman, Random(6)));
    Future<int> save() =>
        repo.saveResult(titleId: roman.id, attempt: a, contentVersion: 1);
    await save();
    final latest = await save();
    expect((await repo.result(roman.id, null))!.id, latest);
    expect((await repo.result(roman.id, 999))!.id, latest);
    expect(await repo.result('chanakya', latest), isNull);
  });

  test('clear my data empties quiz tables', () async {
    final qs = await repo.startAttempt(roman, Random(7));
    await repo.markSeen(qs.first);
    await repo.saveResult(
      titleId: roman.id,
      attempt: attemptOf(qs),
      contentVersion: 1,
    );
    await db.clearMyData();
    expect(await db.select(db.quizSeen).get(), isEmpty);
    // Results become tombstones until synced (CONTRACTS 15.5).
    expect(
      await (db.select(db.quizResults)..where((t) => t.deleted.equals(false))).get(),
      isEmpty,
    );
  });
}
