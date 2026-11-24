// Fact of the day (CONTRACTS 20, DESIGN_SPEC 15.2): one bundled fact per
// local day, no network. A missing, empty or broken list hides the card.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Day 0 of the pick rule (CONTRACTS 20).
final factEpoch = DateTime.utc(2026, 1, 1);

class Fact {
  const Fact({required this.id, required this.titleId, required this.text});

  final String id;
  final String titleId;
  final String text;
}

/// Parses facts.json. Never throws: anything unusable gives an empty list,
/// and entries missing a field are skipped.
List<Fact> parseFacts(String source) {
  try {
    final root = jsonDecode(source);
    final list = root is Map ? root['facts'] : null;
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map &&
            e['id'] is String &&
            e['title_id'] is String &&
            e['text'] is String &&
            (e['text'] as String).trim().isNotEmpty)
          Fact(
            id: e['id'] as String,
            titleId: e['title_id'] as String,
            text: (e['text'] as String).trim(),
          ),
    ];
  } catch (_) {
    return const [];
  }
}

/// `daysSince(2026-01-01, date) mod length` from the calendar day alone
/// (UTC maths, so daylight saving never shifts it). Wraps; never negative.
int factIndexFor(DateTime localDate, int length) {
  if (length <= 0) return 0;
  final day = DateTime.utc(localDate.year, localDate.month, localDate.day);
  return day.difference(factEpoch).inDays % length;
}

Fact? pickFact(List<Fact> facts, DateTime localDate) =>
    facts.isEmpty ? null : facts[factIndexFor(localDate, facts.length)];

/// Loads the raw asset text. Tests override it.
final factsSourceProvider = Provider<Future<String> Function()>(
  (_) =>
      () => rootBundle.loadString('assets/facts/facts.json'),
);

final factsProvider = FutureProvider<List<Fact>>((ref) async {
  try {
    return parseFacts(await ref.watch(factsSourceProvider)());
  } catch (_) {
    return const [];
  }
});

/// Keyed by the local calendar day, so a new day picks the next fact.
final todayFactProvider = Provider.family<Fact?, DateTime>(
  (ref, day) => pickFact(ref.watch(factsProvider).value ?? const [], day),
);
