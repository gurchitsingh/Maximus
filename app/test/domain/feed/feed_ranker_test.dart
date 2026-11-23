// CONTRACTS 7.2 and 10: weights, no same title twice, every 5th try card,
// dislike exclusion, seen cycle.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/domain/feed/feed_ranker.dart';
import 'package:maximus/domain/match/match_scores.dart';

FeedCandidate own(String title, int n) =>
    FeedCandidate(factId: '$title.f$n', titleId: title);

FeedCandidate tryCard(String title, int n) =>
    FeedCandidate(factId: '$title.f$n', titleId: title, isTry: true);

int? noPct(String _) => null;

List<FeedCandidate> dealAll(FeedDeck deck, int n, {PctOf pct = noPct}) => [
  for (var i = 0; i < n; i++) ?deck.deal(pct),
];

void main() {
  group('feedWeight', () {
    test('is max(1, pct - 39), and 1 on a cold start', () {
      expect(feedWeight(null), 1);
      expect(feedWeight(40), 1);
      expect(feedWeight(39), 1);
      expect(feedWeight(66), 27);
      expect(feedWeight(99), 60);
    });
  });

  group('FeedDeck.deal', () {
    test('an empty pool deals nothing', () {
      final deck = FeedDeck(random: Random(1));
      expect(deck.deal(noPct), isNull);
      expect(deck.hasCandidates, isFalse);
    });

    test('higher match is picked more often', () {
      var high = 0;
      for (var seed = 0; seed < 2000; seed++) {
        final deck = FeedDeck(random: Random(seed))
          ..setPool(
            own: [own('a', 1), own('b', 1)],
            tries: const [],
            current: 0,
          );
        final first = deck.deal((id) => id == 'a' ? 99 : 40)!;
        if (first.titleId == 'a') high++;
      }
      // Weights 60 : 1.
      expect(high / 2000, closeTo(60 / 61, 0.02));
    });

    test('never the previous title while another title has candidates', () {
      final deck = FeedDeck(random: Random(7))
        ..setPool(
          own: [
            for (var i = 0; i < 6; i++) own('a', i),
            for (var i = 0; i < 6; i++) own('b', i),
          ],
          tries: const [],
          current: 0,
        );
      final cards = dealAll(deck, 12);
      for (var i = 1; i < cards.length; i++) {
        expect(cards[i].titleId, isNot(cards[i - 1].titleId));
      }
    });

    test('the same title repeats only when it is the only one left', () {
      final deck = FeedDeck(random: Random(3))
        ..setPool(
          own: [own('a', 1), own('a', 2), own('a', 3)],
          tries: const [],
          current: 0,
        );
      expect(dealAll(deck, 3).map((c) => c.factId).toSet(), hasLength(3));
    });

    test('every 5th card is a try card while one is left', () {
      final deck = FeedDeck(random: Random(11))
        ..setPool(
          own: [
            for (var i = 0; i < 8; i++) own('a', i),
            for (var i = 0; i < 8; i++) own('b', i),
          ],
          tries: [tryCard('t', 1), tryCard('u', 1)],
          current: 0,
        );
      final cards = dealAll(deck, 12);
      for (var i = 0; i < cards.length; i++) {
        expect(
          cards[i].isTry,
          i == 4 || i == 9,
          reason: 'card ${i + 1} of the feed',
        );
      }
    });

    test('with no try card left, the 5th card is an own card', () {
      final deck = FeedDeck(random: Random(5))
        ..setPool(
          own: [
            for (var i = 0; i < 4; i++) own('a', i),
            for (var i = 0; i < 4; i++) own('b', i),
          ],
          tries: const [],
          current: 0,
        );
      expect(dealAll(deck, 5)[4].isTry, isFalse);
    });

    test('a cold start with only try cards still fills the feed', () {
      final deck = FeedDeck(random: Random(2))
        ..setPool(
          own: const [],
          tries: [tryCard('t', 1), tryCard('u', 1), tryCard('v', 1)],
          current: 0,
        );
      expect(dealAll(deck, 3).every((c) => c.isTry), isTrue);
    });

    test('disliked facts are never dealt', () {
      final deck = FeedDeck(random: Random(9))
        ..setPool(
          own: [own('a', 1), own('b', 1), own('c', 1)],
          tries: const [],
          current: 0,
        )
        ..setDisliked({'b.f1'});
      final ids = dealAll(deck, 8).map((c) => c.factId).toSet();
      expect(ids, {'a.f1', 'c.f1'});
    });

    test('facts seen earlier come after unseen ones', () {
      final deck = FeedDeck(random: Random(4), seen: {'a.f1'})
        ..setPool(own: [own('a', 1), own('b', 1)], tries: const [], current: 0);
      expect(deck.deal(noPct)!.factId, 'b.f1');
    });

    test('when all are seen the cycle repeats', () {
      final deck = FeedDeck(random: Random(6), seen: {'a.f1', 'b.f1'})
        ..setPool(own: [own('a', 1), own('b', 1)], tries: const [], current: 0);
      final cards = dealAll(deck, 6);
      expect(cards, hasLength(6));
      for (var i = 1; i < cards.length; i++) {
        expect(cards[i].factId, isNot(cards[i - 1].factId));
      }
    });

    test('a single candidate is not dealt twice in a row', () {
      final deck = FeedDeck(random: Random(1))
        ..setPool(own: [own('a', 1)], tries: const [], current: 0);
      expect(deck.deal(noPct), isNotNull);
      expect(deck.deal(noPct), isNull);
    });
  });

  group('FeedDeck.setPool', () {
    test('keeps history, drops the look-ahead, and re-deals', () {
      final deck = FeedDeck(random: Random(8))
        ..setPool(
          own: [own('a', 1), own('b', 1), own('c', 1)],
          tries: const [],
          current: 0,
        );
      dealAll(deck, 3);
      final kept = deck.cards.first;
      final index = deck.setPool(
        own: [own('a', 1), own('b', 1), own('c', 1)],
        tries: const [],
        current: 0,
      );
      expect(index, 0);
      expect(deck.cards, [kept]);
      expect(deck.deal(noPct), isNotNull);
    });

    test('a removed title leaves the deck', () {
      final deck = FeedDeck(random: Random(8))
        ..setPool(own: [own('a', 1), own('b', 1)], tries: const [], current: 0);
      dealAll(deck, 2);
      final survivor = deck.cards.first.titleId == 'a' ? 'a' : 'b';
      final index = deck.setPool(
        own: [own(survivor, 1)],
        tries: const [],
        current: 1,
      );
      expect(deck.cards.map((c) => c.titleId), [survivor]);
      expect(index, 0);
    });

    test('a try card becomes an own card when its title is added', () {
      final deck = FeedDeck(random: Random(8))
        ..setPool(own: const [], tries: [tryCard('t', 1)], current: 0);
      deck.deal(noPct);
      deck.setPool(own: [own('t', 1)], tries: const [], current: 0);
      expect(deck.cards.single.isTry, isFalse);
    });

    test('an own fact wins over the same fact in the try pool', () {
      final deck = FeedDeck(random: Random(8))
        ..setPool(own: [own('t', 1)], tries: [tryCard('t', 1)], current: 0);
      expect(deck.deal(noPct)!.isTry, isFalse);
      expect(deck.deal(noPct), isNull);
    });
  });

  group('tryTitleIds', () {
    MatchTitle t(String id, int rank) => MatchTitle(
      id: id,
      name: id,
      group: 'g',
      era: 'e',
      region: 'r',
      themes: const ['x'],
      rank: rank,
      lessonCount: 1,
    );

    test('top 5 by rank on a cold start', () {
      final titles = [for (var i = 1; i <= 7; i++) t('t$i', i)];
      final match = matchScores(titles, MatchSignals.empty);
      expect(tryTitleIds(match, const {}, const {}), [
        't1',
        't2',
        't3',
        't4',
        't5',
      ]);
    });

    test('skips the study list and titles rated down', () {
      final titles = [for (var i = 1; i <= 7; i++) t('t$i', i)];
      final match = matchScores(titles, MatchSignals.empty);
      expect(tryTitleIds(match, const {'t1'}, const {'t2'}), [
        't3',
        't4',
        't5',
        't6',
        't7',
      ]);
    });
  });
}
