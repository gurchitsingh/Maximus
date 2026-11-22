// Recommendation rows built from a MatchResult (CONTRACTS 6.3). Pure Dart.
import 'match_scores.dart';

/// "For you" (Home, Library): top [limit] titles not on the study list, in
/// match order (cold start: rank order, which is what the rows already are).
List<String> forYouIds(
  MatchResult result,
  Set<String> studyList, {
  int limit = 10,
}) => [
  for (final r in result.rows)
    if (!studyList.contains(r.id)) r.id,
].take(limit).toList();

/// "Because you liked X": top [limit] titles t != X with J(t, X) > 0, by J
/// desc, then match order. Empty when X is not in the catalogue.
List<String> becauseYouLikedIds(
  List<MatchTitle> titles,
  String likedId,
  MatchResult result, {
  int limit = 10,
}) {
  MatchTitle? liked;
  for (final t in titles) {
    if (t.id == likedId) liked = t;
  }
  if (liked == null) return const [];
  final position = {
    for (var i = 0; i < result.rows.length; i++) result.rows[i].id: i,
  };
  final tags = liked.tags;
  final cands =
      [
        for (final t in titles)
          if (t.id != likedId) (id: t.id, j: jaccard(t.tags, tags)),
      ].where((c) => c.j > 0).toList()..sort((a, b) {
        if (a.j != b.j) return b.j.compareTo(a.j);
        return (position[a.id] ?? 1 << 30).compareTo(position[b.id] ?? 1 << 30);
      });
  return [for (final c in cands.take(limit)) c.id];
}
