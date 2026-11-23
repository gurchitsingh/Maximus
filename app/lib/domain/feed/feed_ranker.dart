// Feed order on the device (CONTRACTS 7.2). Pure Dart: no Flutter, no I/O.
import 'dart:math';

import 'package:meta/meta.dart';

import '../match/match_scores.dart';

/// One fact the feed can show. [isTry] = from the "try this" pool.
@immutable
class FeedCandidate {
  const FeedCandidate({
    required this.factId,
    required this.titleId,
    this.isTry = false,
  });

  final String factId;
  final String titleId;
  final bool isTry;

  @override
  bool operator ==(Object other) =>
      other is FeedCandidate &&
      other.factId == factId &&
      other.titleId == titleId &&
      other.isTry == isTry;

  @override
  int get hashCode => Object.hash(factId, titleId, isTry);
}

/// Match % of a title; null on a cold start.
typedef PctOf = int? Function(String titleId);

/// `max(1, pct(title) - 39)`; 1 on a cold start.
double feedWeight(int? pct) => pct == null ? 1 : max(1, pct - 39).toDouble();

/// The titles to ask `/v1/feed` for: top [count] by match (by rank on a cold
/// start), not on the study list and not rated down.
List<String> tryTitleIds(
  MatchResult match,
  Set<String> studyIds,
  Set<String> ratedDown, {
  int count = 5,
}) => match.order
    .where((id) => !studyIds.contains(id) && !ratedDown.contains(id))
    .take(count)
    .toList();

/// The cards dealt so far, plus the pool the next ones come from.
class FeedDeck {
  FeedDeck({Random? random, Iterable<String> seen = const []})
    : _random = random ?? Random(),
      _seen = {...seen};

  final Random _random;

  /// Facts with `seen_at`, until a cycle ends.
  final Set<String> _seen;

  /// Facts dealt in this cycle (a dealt card may not have reached 1 s yet).
  final Set<String> _dealt = {};
  Set<String> _disliked = const {};
  List<FeedCandidate> _own = const [];
  List<FeedCandidate> _tries = const [];

  /// Dealt cards in page order. A fact can return in a later cycle.
  final List<FeedCandidate> cards = [];

  List<FeedCandidate> get _live =>
      [..._own, ..._tries].where((c) => !_disliked.contains(c.factId)).toList();

  bool get hasCandidates => _live.isNotEmpty;

  void markSeen(String factId) => _seen.add(factId);

  void setDisliked(Set<String> factIds) => _disliked = factIds;

  /// Replaces the pool. Cards after [current] are dropped so they are dealt
  /// again from the new pool, and cards no longer in it leave the deck.
  /// Returns the page to show.
  int setPool({
    required List<FeedCandidate> own,
    required List<FeedCandidate> tries,
    required int current,
  }) {
    final ownIds = {for (final c in own) c.factId};
    _own = own;
    _tries = [
      for (final c in tries)
        if (!ownIds.contains(c.factId)) c,
    ];
    final byId = {
      for (final c in [..._tries, ..._own]) c.factId: c,
    };

    final head = cards.take(current + 1).toList();
    for (final c in cards.skip(current + 1)) {
      _dealt.remove(c.factId);
    }
    cards
      ..clear()
      ..addAll([
        for (final c in head)
          if (byId[c.factId] != null) byId[c.factId]!,
      ]);
    _dealt.addAll(cards.map((c) => c.factId));

    return max(0, cards.length - 1);
  }

  /// Deals the next card (7.2), or null when nothing else can follow.
  FeedCandidate? deal(PctOf pct) {
    final live = _live;
    if (live.isEmpty) return null;
    final previous = cards.isEmpty ? null : cards.last;
    if (live.length == 1 && live.single.factId == previous?.factId) return null;

    var unseen = [
      for (final c in live)
        if (!_seen.contains(c.factId) && !_dealt.contains(c.factId)) c,
    ];
    if (unseen.isEmpty) {
      // Every candidate is seen: ignore the marks and start a new cycle.
      _seen.clear();
      _dealt.clear();
      unseen = [
        for (final c in live)
          if (c.factId != previous?.factId) c,
      ];
    }

    final wantTry = (cards.length + 1) % 5 == 0;
    final preferred = unseen.where((c) => c.isTry == wantTry).toList();
    final other = unseen.where((c) => c.isTry != wantTry).toList();
    bool freshTitle(FeedCandidate c) => c.titleId != previous?.titleId;

    // The "never the same title twice" rule outranks the try-card slot.
    final pool = [
      preferred.where(freshTitle).toList(),
      other.where(freshTitle).toList(),
      preferred,
      other,
    ].firstWhere((p) => p.isNotEmpty);

    final card = _weightedPick(pool, pct);
    cards.add(card);
    _dealt.add(card.factId);
    return card;
  }

  FeedCandidate _weightedPick(List<FeedCandidate> pool, PctOf pct) {
    final weights = [for (final c in pool) feedWeight(pct(c.titleId))];
    final total = weights.reduce((a, b) => a + b);
    var r = _random.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r < 0) return pool[i];
    }
    return pool.last;
  }
}
