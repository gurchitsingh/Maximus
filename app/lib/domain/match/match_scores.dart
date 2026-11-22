// On-device match % (CONTRACTS 6). Pure Dart: no Flutter, no I/O.
// Reference implementation: tools/validate_samples.py `match_scores`;
// test vectors: docs/examples/match-cases.json.
import 'package:meta/meta.dart';

/// The catalogue fields match % needs (summary fields of a title).
@immutable
class MatchTitle {
  const MatchTitle({
    required this.id,
    required this.name,
    required this.group,
    required this.era,
    required this.region,
    required this.themes,
    required this.rank,
    required this.lessonCount,
    this.linkedTitleIds = const [],
  });

  final String id;
  final String name;
  final String group;
  final String era;
  final String region;
  final List<String> themes;
  final int rank;
  final int lessonCount;
  final List<String> linkedTitleIds;

  /// `{"g:"+group, "e:"+era, "r:"+region} ∪ {"t:"+theme}` (6.1).
  Set<String> get tags => {
    'g:$group',
    'e:$era',
    'r:$region',
    for (final t in themes) 't:$t',
  };
}

/// Feed reactions on one title's facts (6.1 feed row).
@immutable
class FeedCounts {
  const FeedCounts({this.likedOrSaved = 0, this.disliked = 0});

  /// Facts liked or saved; a fact both liked and saved counts once.
  final int likedOrSaved;
  final int disliked;
}

/// Every signal source of 6.1, read from the drift tables.
@immutable
class MatchSignals {
  const MatchSignals({
    this.topicPicks = const [],
    this.leaderPicks = const [],
    this.ratings = const {},
    this.studyList = const [],
    this.lessonsCompleted = const {},
    this.feed = const {},
  });

  final List<String> topicPicks;
  final List<String> leaderPicks;

  /// title id -> -1 | 0 | 1.
  final Map<String, int> ratings;
  final List<String> studyList;

  /// title id -> number of completed lessons.
  final Map<String, int> lessonsCompleted;
  final Map<String, FeedCounts> feed;

  static const empty = MatchSignals();
}

/// Signal kinds, in the reason tie-break order of 6.2 step 3.
enum SignalKind {
  ratingUp('because you liked'),
  topicPick('because you picked'),
  leaderPick('because you chose'),
  leaderLink('because you chose'),
  studyList('because you added'),
  lessonsRead('because you read'),
  feedUp('because you liked facts about'),

  // Negative or zero kinds never give a reason.
  ratingOkay(null),
  ratingDown(null),
  feedDown(null);

  const SignalKind(this.reasonPrefix);
  final String? reasonPrefix;
}

/// Weights (6.1).
abstract final class MatchWeights {
  static const topicPick = 3.0;
  static const leaderPick = 3.0;
  static const leaderLink = 2.0;
  static const ratingUp = 4.0;
  static const ratingOkay = 0.0;
  static const ratingDown = -4.0;
  static const studyList = 2.0;
  static const lessonsRead = 2.0;
  static const feedStep = 0.5;
  static const feedCap = 4;
}

const reasonFallback = 'because of what you picked';

class _Signal {
  const _Signal(this.titleId, this.weight, this.kind, this.subjectId);
  final String titleId;
  final double weight;
  final SignalKind kind;

  /// Who the reason line names: the title itself, or the picking leader.
  final String subjectId;
}

@immutable
class MatchRow {
  const MatchRow({
    required this.id,
    required this.raw,
    required this.pct,
    required this.reason,
    required this.rank,
  });

  final String id;

  /// null on a cold start (no badges).
  final double? raw;
  final int? pct;

  /// "because you liked Ancient Greece", or null.
  final String? reason;
  final int rank;
}

@immutable
class MatchResult {
  MatchResult({required this.badges, required this.rows})
    : byId = {for (final r in rows) r.id: r};

  /// false = cold start: no badges anywhere, rows in rank order.
  final bool badges;

  /// Every catalogue title in match order (6.2).
  final List<MatchRow> rows;
  final Map<String, MatchRow> byId;

  int? pctOf(String id) => badges ? byId[id]?.pct : null;
  String? reasonOf(String id) => badges ? byId[id]?.reason : null;

  /// Ids in match order.
  List<String> get order => [for (final r in rows) r.id];
}

/// Jaccard similarity of two tag sets; J(t, t) = 1.
double jaccard(Set<String> a, Set<String> b) {
  final union = a.union(b).length;
  return union == 0 ? 0 : a.intersection(b).length / union;
}

List<_Signal> _collect(MatchSignals sig, Map<String, MatchTitle> byId) {
  final out = <_Signal>[];
  for (final id in sig.topicPicks) {
    out.add(_Signal(id, MatchWeights.topicPick, SignalKind.topicPick, id));
  }
  for (final id in sig.leaderPicks) {
    out.add(_Signal(id, MatchWeights.leaderPick, SignalKind.leaderPick, id));
    for (final x in byId[id]?.linkedTitleIds ?? const <String>[]) {
      out.add(_Signal(x, MatchWeights.leaderLink, SignalKind.leaderLink, id));
    }
  }
  sig.ratings.forEach((id, v) {
    final (w, k) = switch (v) {
      1 => (MatchWeights.ratingUp, SignalKind.ratingUp),
      -1 => (MatchWeights.ratingDown, SignalKind.ratingDown),
      _ => (MatchWeights.ratingOkay, SignalKind.ratingOkay),
    };
    out.add(_Signal(id, w, k, id));
  });
  for (final id in sig.studyList) {
    out.add(_Signal(id, MatchWeights.studyList, SignalKind.studyList, id));
  }
  sig.lessonsCompleted.forEach((id, n) {
    final lc = byId[id]?.lessonCount ?? 0;
    final frac = lc == 0 ? 0.0 : (n / lc).clamp(0.0, 1.0);
    out.add(
      _Signal(id, MatchWeights.lessonsRead * frac, SignalKind.lessonsRead, id),
    );
  });
  sig.feed.forEach((id, f) {
    double capped(int n) =>
        MatchWeights.feedStep *
        (n < MatchWeights.feedCap ? n : MatchWeights.feedCap);
    out.add(_Signal(id, capped(f.likedOrSaved), SignalKind.feedUp, id));
    out.add(_Signal(id, -capped(f.disliked), SignalKind.feedDown, id));
  });
  // Only signals whose title and subject are in the current catalogue.
  return [
    for (final s in out)
      if (byId.containsKey(s.titleId) &&
          byId.containsKey(s.subjectId) &&
          s.weight != 0)
        s,
  ];
}

int _byRankId(MatchTitle a, MatchTitle b) =>
    a.rank != b.rank ? a.rank.compareTo(b.rank) : a.id.compareTo(b.id);

/// CONTRACTS 6.2. [titles] is the current catalogue.
MatchResult matchScores(List<MatchTitle> titles, MatchSignals sig) {
  final byId = {for (final t in titles) t.id: t};
  final signals = _collect(sig, byId);
  final w = <String, double>{};
  for (final s in signals) {
    w[s.titleId] = (w[s.titleId] ?? 0) + s.weight;
  }
  w.removeWhere((_, v) => v == 0);

  if (w.isEmpty) {
    final sorted = [...titles]..sort(_byRankId);
    return MatchResult(
      badges: false,
      rows: [
        for (final t in sorted)
          MatchRow(id: t.id, raw: null, pct: null, reason: null, rank: t.rank),
      ],
    );
  }

  final tags = {for (final t in titles) t.id: t.tags};
  double j(String a, String b) => jaccard(tags[a]!, tags[b]!);

  final rows = <MatchRow>[];
  for (final t in titles) {
    var raw = 0.0;
    w.forEach((s, ws) => raw += ws * j(t.id, s));
    final pct = (50 + 49 * raw / (4 + raw.abs()) + 0.5).floor().clamp(40, 99);
    rows.add(
      MatchRow(
        id: t.id,
        raw: raw,
        pct: pct,
        reason: raw > 0 ? _reason(t.id, w, signals, byId, j) : null,
        rank: t.rank,
      ),
    );
  }

  rows.sort((a, b) {
    if (a.pct != b.pct) return b.pct!.compareTo(a.pct!);
    final d = a.raw! - b.raw!;
    if (d.abs() > 1e-9) return d > 0 ? -1 : 1;
    if (a.rank != b.rank) return a.rank.compareTo(b.rank);
    return a.id.compareTo(b.id);
  });
  return MatchResult(badges: true, rows: rows);
}

/// Reason line, 6.2 steps 2 to 5.
String _reason(
  String t,
  Map<String, double> w,
  List<_Signal> signals,
  Map<String, MatchTitle> byId,
  double Function(String, String) j,
) {
  final cands =
      [
        for (final e in w.entries)
          if (e.key != t && e.value > 0 && j(t, e.key) > 0)
            (id: e.key, contrib: e.value * j(t, e.key)),
      ]..sort((a, b) {
        if (a.contrib != b.contrib) return b.contrib.compareTo(a.contrib);
        final ra = byId[a.id]!.rank, rb = byId[b.id]!.rank;
        if (ra != rb) return ra.compareTo(rb);
        return a.id.compareTo(b.id);
      });

  for (final c in cands) {
    final positive =
        [
          for (final s in signals)
            if (s.titleId == c.id &&
                s.weight > 0 &&
                s.kind.reasonPrefix != null &&
                s.subjectId != t)
              s,
        ]..sort((a, b) {
          if (a.weight != b.weight) return b.weight.compareTo(a.weight);
          if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
          return a.subjectId.compareTo(b.subjectId);
        });
    if (positive.isNotEmpty) {
      final s = positive.first;
      return '${s.kind.reasonPrefix} ${byId[s.subjectId]!.name}';
    }
  }
  return reasonFallback;
}
