// Home "Your quiz scores" (DESIGN_SPEC 7.15, CONTRACTS 7.1): the best score
// of the two most recently attempted titles, or the empty tile.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import '../../data/models/title.dart';
import '../../data/providers.dart';
import 'quiz_providers.dart';

class QuizScores extends ConsumerWidget {
  const QuizScores({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider).value;
    final tiles = <(String, TitleSummary)>[];
    for (final s in ref.watch(quizBestScoresProvider)) {
      final t = catalogue?.title(s.titleId);
      if (t != null) tiles.add(('${s.score}/${s.total}', t));
      if (tiles.length == 2) break;
    }
    if (tiles.isEmpty) return const EmptyScores();

    Widget tile(int i) => i < tiles.length
        ? ScoreTile(score: tiles[i].$1, topic: tiles[i].$2.name)
        : const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tile(0)),
          const SizedBox(width: 10),
          Expanded(child: tile(1)),
        ],
      ),
    );
  }
}
