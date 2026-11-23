// CONTRACTS 7.1: quiz picker (no repeats until the bank is exhausted) and
// scoring.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/domain/quiz/quiz_picker.dart';
import 'package:maximus/domain/quiz/quiz_scoring.dart';

List<String> bankOf(int n) => [for (var i = 1; i <= n; i++) 'q$i'];

void main() {
  group('pickQuiz', () {
    test('takes 6 distinct unseen questions, no new cycle', () {
      final seen = {'q1', 'q2', 'q3'};
      for (var s = 0; s < 50; s++) {
        final p = pickQuiz(bank: bankOf(10), seen: seen, random: Random(s));
        expect(p.ids, hasLength(6));
        expect(p.ids.toSet(), hasLength(6));
        expect(p.ids.toSet().intersection(seen), isEmpty);
        expect(p.newCycle, isFalse);
      }
    });

    test('exactly 6 unseen is not a new cycle', () {
      final p = pickQuiz(
        bank: bankOf(10),
        seen: {'q1', 'q2', 'q3', 'q4'},
        random: Random(1),
      );
      expect(p.ids.toSet(), {'q5', 'q6', 'q7', 'q8', 'q9', 'q10'});
      expect(p.newCycle, isFalse);
    });

    test('under 6 unseen: all unseen first, filled from the rest', () {
      final seen = {for (final id in bankOf(7)) id};
      for (var s = 0; s < 50; s++) {
        final p = pickQuiz(bank: bankOf(10), seen: seen, random: Random(s));
        expect(p.newCycle, isTrue);
        expect(p.ids, hasLength(6));
        expect(p.ids.toSet(), hasLength(6));
        expect(p.ids.take(3).toSet(), {'q8', 'q9', 'q10'});
      }
    });

    test('everything seen starts a new cycle over the whole bank', () {
      final p = pickQuiz(
        bank: bankOf(6),
        seen: bankOf(6).toSet(),
        random: Random(2),
      );
      expect(p.newCycle, isTrue);
      expect(p.ids.toSet(), bankOf(6).toSet());
    });

    test('seen ids that left the bank are ignored', () {
      final p = pickQuiz(
        bank: bankOf(6),
        seen: {'gone1', 'gone2'},
        random: Random(3),
      );
      expect(p.newCycle, isFalse);
      expect(p.ids.toSet(), bankOf(6).toSet());
    });

    test('the same seed gives the same pick', () {
      List<String> pick() =>
          pickQuiz(bank: bankOf(20), seen: const {}, random: Random(9)).ids;
      expect(pick(), pick());
    });

    test('no question repeats until the bank is exhausted', () {
      final bank = bankOf(18);
      final seen = <String>{};
      final random = Random(5);
      for (var attempt = 0; attempt < 3; attempt++) {
        final p = pickQuiz(bank: bank, seen: seen, random: random);
        expect(p.newCycle, isFalse);
        expect(p.ids.toSet().intersection(seen), isEmpty);
        seen.addAll(p.ids);
      }
      expect(seen, bank.toSet());
      expect(pickQuiz(bank: bank, seen: seen, random: random).newCycle, isTrue);
    });
  });

  group('QuizAttempt', () {
    QuizAttempt attempt() => QuizAttempt(
      questionIds: bankOf(6),
      correctIndexes: const [0, 1, 2, 3, 0, 1],
    );

    test('scores correct answers and lists the missed in shown order', () {
      final a = attempt();
      for (final (q, option) in [
        (0, 0),
        (1, 0),
        (2, 2),
        (3, 0),
        (4, 0),
        (5, 1),
      ]) {
        expect(a.answer(q, option), isTrue);
      }
      expect(a.score, 4);
      expect(a.wrongIds, ['q2', 'q4']);
    });

    test('only the first answer counts', () {
      final a = attempt();
      expect(a.answer(0, 3), isTrue);
      expect(a.answer(0, 0), isFalse);
      expect(a.answerAt(0), 3);
      expect(a.isCorrect(0), isFalse);
      expect(a.score, 0);
    });

    test('unanswered questions count as missed', () {
      final a = attempt()..answer(0, 0);
      expect(a.score, 1);
      expect(a.wrongIds, ['q2', 'q3', 'q4', 'q5', 'q6']);
    });
  });

  test('result copy follows the score bands', () {
    for (final s in [0, 1, 2]) {
      expect(quizResultMessage(s), 'A start. The lessons will help.');
    }
    for (final s in [3, 4]) {
      expect(quizResultMessage(s), 'Good going. A few to revisit.');
    }
    for (final s in [5, 6]) {
      expect(quizResultMessage(s), 'Ave! Very nicely done.');
    }
  });

  test('only a perfect or near-perfect score celebrates', () {
    expect(
      [for (var s = 0; s <= 6; s++) celebratesQuizScore(s)],
      [false, false, false, false, false, true, true],
    );
  });

  group('bestScores', () {
    QuizScoreEntry e(int id, String title, int score) =>
        QuizScoreEntry(id: id, titleId: title, score: score, total: 6);

    test('best per title, titles by latest attempt', () {
      final out = bestScores([
        e(1, 'rome', 5),
        e(2, 'greece', 3),
        e(3, 'rome', 2),
        e(4, 'egypt', 6),
        e(5, 'greece', 4),
      ]);
      expect(out.map((x) => (x.titleId, x.score)), [
        ('greece', 4),
        ('egypt', 6),
        ('rome', 5),
      ]);
    });

    test('a tie keeps the latest attempt', () {
      final out = bestScores([
        e(1, 'rome', 4),
        e(2, 'rome', 4),
        e(3, 'rome', 1),
      ]);
      expect(out.single.id, 2);
    });

    test('no attempts, no scores', () {
      expect(bestScores(const []), isEmpty);
    });
  });
}
