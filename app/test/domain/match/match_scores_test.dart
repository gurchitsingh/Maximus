// Match % against the shared test vectors (CONTRACTS 6.4, section 10):
// docs/examples/match-cases.json, the same file tools/validate_samples.py
// checks against the Python reference `match_scores`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/domain/match/match_scores.dart';

MatchSignals _signals(Map<String, dynamic> j) {
  final feed = <String, FeedCounts>{};
  for (final e
      in ((j['feed'] ?? <String, dynamic>{}) as Map<String, dynamic>).entries) {
    final f = e.value as Map<String, dynamic>;
    feed[e.key] = FeedCounts(
      likedOrSaved: (f['liked_or_saved'] ?? 0) as int,
      disliked: (f['disliked'] ?? 0) as int,
    );
  }
  return MatchSignals(
    topicPicks: [...?(j['topic_picks'] as List?)?.cast<String>()],
    leaderPicks: [...?(j['leader_picks'] as List?)?.cast<String>()],
    ratings: {
      for (final e
          in ((j['ratings'] ?? <String, dynamic>{}) as Map<String, dynamic>)
              .entries)
        e.key: e.value as int,
    },
    studyList: [...?(j['study_list'] as List?)?.cast<String>()],
    lessonsCompleted: {
      for (final e
          in ((j['lessons_completed'] ?? <String, dynamic>{})
                  as Map<String, dynamic>)
              .entries)
        e.key: e.value as int,
    },
    feed: feed,
  );
}

MatchTitle _title(Map<String, dynamic> j) => MatchTitle(
  id: j['id'] as String,
  name: j['name'] as String,
  group: j['group'] as String,
  era: j['era'] as String,
  region: j['region'] as String,
  themes: (j['themes'] as List).cast<String>(),
  rank: j['rank'] as int,
  lessonCount: j['lesson_count'] as int,
  linkedTitleIds: (j['linked_title_ids'] as List).cast<String>(),
);

void main() {
  final file = File('../docs/examples/match-cases.json');
  final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final titles = [
    for (final t in doc['titles'] as List) _title(t as Map<String, dynamic>),
  ];
  final cases = (doc['cases'] as List).cast<Map<String, dynamic>>();

  test('fixture has the 6 documented cases', () {
    expect(cases, hasLength(6));
  });

  for (final c in cases) {
    test(c['name'], () {
      final result = matchScores(
        titles,
        _signals(c['signals'] as Map<String, dynamic>),
      );
      final expected = (c['expected'] as List).cast<Map<String, dynamic>>();

      expect(result.badges, c['badges'], reason: 'badges shown');
      expect(
        result.rows.map((r) => r.id).toList(),
        expected.map((e) => e['id']).toList(),
        reason: 'order',
      );
      for (var i = 0; i < expected.length; i++) {
        final e = expected[i];
        final r = result.rows[i];
        final id = e['id'];
        if (e['raw'] == null) {
          expect(r.raw, isNull, reason: '$id raw');
        } else {
          expect(
            r.raw,
            closeTo((e['raw'] as num).toDouble(), 1e-4),
            reason: '$id raw',
          );
        }
        expect(r.pct, e['pct'], reason: '$id pct');
        expect(r.reason, e['reason'], reason: '$id reason');
      }
    });
  }

  group('rules beyond the vectors', () {
    test('signals on titles outside the catalogue are dropped', () {
      final r = matchScores(
        titles,
        const MatchSignals(topicPicks: ['not-a-title'], studyList: ['nope']),
      );
      expect(r.badges, isFalse);
    });

    test('a leader link from an unknown leader is dropped', () {
      // The leader is not in the catalogue, so its +2 link must not count.
      final r = matchScores(
        titles.where((t) => t.id != 'shivaji-maharaj').toList(),
        const MatchSignals(leaderPicks: ['shivaji-maharaj']),
      );
      expect(r.badges, isFalse);
    });

    test('okay rating alone is no signal (cold start)', () {
      final r = matchScores(
        titles,
        const MatchSignals(ratings: {'roman-history': 0}),
      );
      expect(r.badges, isFalse);
      expect(r.rows.first.id, 'roman-history');
    });

    test('pct stays inside 40..99 for huge signals', () {
      final r = matchScores(
        titles,
        // 400 picks of one title: raw about 1200, squash ≈ 0.997 -> 99.
        MatchSignals(topicPicks: List.filled(400, 'ww2')),
      );
      for (final row in r.rows) {
        expect(row.pct, inInclusiveRange(40, 99));
      }
      expect(r.rows.first.id, 'ww2');
      expect(r.rows.first.pct, 99);
    });

    test('byId gives the same rows as the ordered list', () {
      final r = matchScores(titles, const MatchSignals(topicPicks: ['ww2']));
      expect(r.byId['ww2'], same(r.rows.firstWhere((x) => x.id == 'ww2')));
      expect(r.pctOf('ww2'), r.byId['ww2']!.pct);
      expect(r.pctOf('missing'), isNull);
    });
  });
}
