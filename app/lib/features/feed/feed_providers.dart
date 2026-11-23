// Feed wiring. Kept here, not in data/providers.dart, so the parallel
// sessions share as little as possible.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../data/db/app_database.dart';
import '../../data/dev/dev_feed_source.dart';
import '../../data/models/catalogue.dart';
import '../../data/providers.dart';
import '../../data/repositories/feed_repository.dart';
import '../../domain/match/match_scores.dart';

/// Bundled samples until S12 wires GET /v1/feed.
final feedSourceProvider = Provider<FeedSource>(
  (_) => DevFeedSource(rootBundle),
);

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(
    ref.watch(contentRepositoryProvider),
    ref.watch(feedSourceProvider),
  ),
);

/// Everything the deck depends on, once every source has loaded.
@immutable
class FeedInputs {
  const FeedInputs({
    required this.catalogue,
    required this.studyIds,
    required this.ratedDown,
    required this.rows,
    required this.match,
  });

  final Catalogue catalogue;
  final Set<String> studyIds;
  final Set<String> ratedDown;
  final List<FeedStateRow> rows;
  final MatchResult match;

  /// Changes only when the pools must be rebuilt (not on a like or a seen).
  String get poolKey => [
    catalogue.catalogueVersion,
    (studyIds.toList()..sort()).join(','),
    (ratedDown.toList()..sort()).join(','),
  ].join('|');

  Set<String> get dislikedFacts => {
    for (final r in rows)
      if (r.reaction == -1) r.factId,
  };
}

final feedInputsProvider = Provider<FeedInputs?>((ref) {
  final catalogue = ref.watch(catalogueProvider).value;
  final loaded = [
    ref.watch(studyListProvider).hasValue,
    ref.watch(ratingsProvider).hasValue,
    ref.watch(progressProvider).hasValue,
    ref.watch(interestsProvider).hasValue,
    ref.watch(feedStateProvider).hasValue,
  ].every((v) => v);
  if (catalogue == null || !loaded) return null;
  return FeedInputs(
    catalogue: catalogue,
    studyIds: ref.watch(studyIdsProvider),
    ratedDown: {
      for (final e in ref.watch(ratingMapProvider).entries)
        if (e.value == -1) e.key,
    },
    rows: ref.watch(feedStateProvider).value!,
    match: ref.watch(matchProvider),
  );
});

/// Save and reaction of one fact, so a tap rebuilds only its buttons.
final feedFactStateProvider =
    Provider.family<({bool saved, int reaction}), String>((ref, factId) {
      final rows = ref.watch(feedStateProvider).value ?? const <FeedStateRow>[];
      for (final r in rows) {
        if (r.factId == factId) return (saved: r.saved, reaction: r.reaction);
      }
      return (saved: false, reaction: 0);
    });
