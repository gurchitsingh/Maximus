// Picks the questions of one attempt (CONTRACTS 7.1). Pure Dart: no Flutter,
// no I/O, and the Random is injected so tests can seed it.
import 'dart:math';

import 'package:meta/meta.dart';

/// Questions in one attempt.
const quizLength = 6;

@immutable
class QuizPick {
  const QuizPick({required this.ids, required this.newCycle});

  /// Question ids in shown order, never the same id twice.
  final List<String> ids;

  /// True when the unseen questions ran out: the caller deletes this title's
  /// `quiz_seen` rows before the attempt starts.
  final bool newCycle;
}

/// `unseen` = [bank] minus [seen]. With at least [count] unseen, a shuffle of
/// them. Otherwise all of them, then a shuffle of the rest of the bank, and
/// a new cycle. Ids in [seen] that left the bank are ignored.
QuizPick pickQuiz({
  required Iterable<String> bank,
  required Set<String> seen,
  required Random random,
  int count = quizLength,
}) {
  final ids = bank.toSet();
  final unseen = ids.where((id) => !seen.contains(id)).toList()
    ..shuffle(random);
  if (unseen.length >= count) {
    return QuizPick(ids: unseen.take(count).toList(), newCycle: false);
  }
  final rest = ids.where(seen.contains).toList()..shuffle(random);
  return QuizPick(
    ids: [...unseen, ...rest].take(count).toList(),
    newCycle: true,
  );
}
