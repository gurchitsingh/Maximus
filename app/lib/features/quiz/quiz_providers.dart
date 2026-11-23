// Quiz wiring. Kept out of data/providers.dart so parallel sessions do not
// collide on that file.
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../domain/quiz/quiz_scoring.dart';

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => QuizRepository(ref.watch(databaseProvider)),
);

/// Overridden with a seeded Random in tests.
final quizRandomProvider = Provider<Random>((_) => Random());

final quizResultsProvider = StreamProvider<List<QuizResultRow>>(
  (ref) => ref.watch(quizRepositoryProvider).watchResults(),
);

/// Best score per title, latest attempted title first (Home tiles).
final quizBestScoresProvider = Provider<List<QuizScoreEntry>>(
  (ref) => bestScores([
    for (final r
        in ref.watch(quizResultsProvider).value ?? const <QuizResultRow>[])
      QuizScoreEntry(
        id: r.id,
        titleId: r.titleId,
        score: r.score,
        total: r.total,
      ),
  ]),
);
