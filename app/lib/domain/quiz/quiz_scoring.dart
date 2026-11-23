// Grading and score summaries (CONTRACTS 7.1). Pure Dart.
import 'package:meta/meta.dart';

/// One run through the picked questions. Only the first answer counts.
class QuizAttempt {
  QuizAttempt({required this.questionIds, required this.correctIndexes})
    : assert(questionIds.length == correctIndexes.length),
      _answers = List<int?>.filled(questionIds.length, null);

  /// Shown order.
  final List<String> questionIds;
  final List<int> correctIndexes;
  final List<int?> _answers;

  int get total => questionIds.length;

  int? answerAt(int question) => _answers[question];

  /// Records the answer. False (and no change) if it was already answered.
  bool answer(int question, int option) {
    if (_answers[question] != null) return false;
    _answers[question] = option;
    return true;
  }

  bool isCorrect(int question) =>
      _answers[question] == correctIndexes[question];

  int get score => [
    for (var i = 0; i < total; i++)
      if (isCorrect(i)) i,
  ].length;

  /// Missed questions in shown order. Unanswered ones count as missed.
  List<String> get wrongIds => [
    for (var i = 0; i < total; i++)
      if (!isCorrect(i)) questionIds[i],
  ];
}

/// The result line under the score.
String quizResultMessage(int score) => switch (score) {
  >= 5 => 'Ave! Very nicely done.',
  >= 3 => 'Good going. A few to revisit.',
  _ => 'A start. The lessons will help.',
};

/// A perfect or near-perfect score gets one gentle confetti (owner, S7).
bool celebratesQuizScore(int score) => score >= 5;

@immutable
class QuizScoreEntry {
  const QuizScoreEntry({
    required this.id,
    required this.titleId,
    required this.score,
    required this.total,
  });

  /// Autoincrement row id: a higher id is a later attempt, even within one
  /// second or after the device clock moved.
  final int id;
  final String titleId;
  final int score;
  final int total;
}

/// Best attempt per title (ties: the latest), titles ordered by their latest
/// attempt, newest first (Home tiles).
List<QuizScoreEntry> bestScores(Iterable<QuizScoreEntry> attempts) {
  final newestFirst = attempts.toList()..sort((a, b) => b.id.compareTo(a.id));
  // A map keeps first-insertion order, which is each title's latest attempt.
  final best = <String, QuizScoreEntry>{};
  for (final a in newestFirst) {
    final current = best[a.titleId];
    if (current == null || a.score > current.score) best[a.titleId] = a;
  }
  return best.values.toList();
}
