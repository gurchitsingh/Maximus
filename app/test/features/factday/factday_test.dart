// S20 Fact of the day (CONTRACTS 20): pick rule, wraparound, hidden when the
// list is empty or broken, placement above On This Day, and a validator for
// every fact in assets/facts/facts.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/repositories/on_this_day_repository.dart';
import 'package:maximus/features/factday/fact_of_the_day.dart';
import 'package:maximus/features/factday/fact_of_the_day_card.dart';
import 'package:maximus/features/on_this_day/on_this_day_card.dart';

import '../../app_harness.dart';
import '../../helpers.dart';

String _json(int n) => jsonEncode({
  'version': 1,
  'facts': [
    for (var i = 0; i < n; i++)
      {'id': 'fd${i + 1}', 'title_id': 'roman-history', 'text': 'Fact $i.'},
  ],
});

/// The sample On This Day, re-dated to today so its card shows.
class _TodayOtd implements OnThisDaySource {
  @override
  Future<String> onThisDayJson(String mmdd) {
    final j = jsonDecode(
      File('assets/dev/on-this-day.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return Future.value(jsonEncode(j..['date'] = mmdd));
  }
}

void main() {
  group('pick rule', () {
    test('index is days since 2026-01-01 mod length', () {
      expect(factIndexFor(DateTime(2026, 1, 1), 12), 0);
      expect(factIndexFor(DateTime(2026, 1, 2), 12), 1);
      // 24 Nov 2026 is day 327; 327 mod 12 = 3.
      expect(factIndexFor(DateTime(2026, 11, 24), 12), 3);
      expect(factIndexFor(DateTime(2026, 11, 24), 100), 27);
    });

    test('same fact all day, whatever the time', () {
      final facts = parseFacts(_json(12));
      final morning = pickFact(facts, DateTime(2026, 11, 24, 0, 1));
      final night = pickFact(facts, DateTime(2026, 11, 24, 23, 59));
      expect(morning!.id, night!.id);
      expect(pickFact(facts, DateTime(2026, 11, 25))!.id, isNot(morning.id));
    });

    test('wraps around after the last fact', () {
      final facts = parseFacts(_json(12));
      final first = pickFact(facts, DateTime(2026, 1, 1))!;
      expect(pickFact(facts, DateTime(2026, 1, 12))!.id, facts.last.id);
      expect(pickFact(facts, DateTime(2026, 1, 13))!.id, first.id);
      // A year on is still inside the list.
      expect(factIndexFor(DateTime(2027, 6, 30), 12), inInclusiveRange(0, 11));
    });

    test('a date before the epoch never goes negative', () {
      expect(factIndexFor(DateTime(2025, 12, 31), 12), 11);
    });

    test('daylight saving does not skip or repeat a day', () {
      for (
        var d = DateTime(2026, 1, 1);
        d.isBefore(DateTime(2027, 1, 1));
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final next = DateTime(d.year, d.month, d.day + 1);
        expect(
          (factIndexFor(next, 7) - factIndexFor(d, 7)) % 7,
          1,
          reason: '$d',
        );
      }
    });

    test('empty and broken lists pick nothing and never throw', () {
      expect(pickFact(const [], DateTime(2026, 11, 24)), isNull);
      expect(parseFacts('{"version":1,"facts":[]}'), isEmpty);
      expect(parseFacts('not json'), isEmpty);
      expect(parseFacts('[1,2]'), isEmpty);
      expect(parseFacts('{"facts":[{"id":"fd1"}]}'), isEmpty);
    });
  });

  group('Home card', () {
    testWidgets('shows the fact above On This Day', (tester) async {
      usePixel8(tester);
      await AppHarness.pump(
        tester,
        overrides: [
          onThisDaySourceProvider.overrideWithValue(_TodayOtd()),
          factsSourceProvider.overrideWithValue(
            () async => jsonEncode({
              'version': 1,
              'facts': [
                for (var i = 0; i < 5; i++)
                  {
                    'id': 'fd00$i',
                    'title_id': 'roman-history',
                    'text': 'Only a test fact.',
                  },
              ],
            }),
          ),
        ],
      );
      expect(find.text(factDateLine(DateTime.now()).toUpperCase()), findsOne);
      expect(find.text('Only a test fact.'), findsOneWidget);
      final fact = tester.getTopLeft(find.text('Only a test fact.')).dy;
      final otd = tester.getTopLeft(find.text(onThisDayKicker(DateTime.now())));
      expect(fact, lessThan(otd.dy));
    });

    testWidgets('an empty list hides the card', (tester) async {
      usePixel8(tester);
      await AppHarness.pump(
        tester,
        overrides: [
          factsSourceProvider.overrideWithValue(() async => _json(0)),
        ],
      );
      expect(find.text('Your quiz scores'), findsOneWidget);
      expect(find.textContaining('FACT OF THE DAY'), findsNothing);
    });

    testWidgets('a list that fails to load hides the card', (tester) async {
      usePixel8(tester);
      await AppHarness.pump(
        tester,
        overrides: [
          factsSourceProvider.overrideWithValue(
            () => Future.error(StateError('missing asset')),
          ),
        ],
      );
      expect(find.text('Your quiz scores'), findsOneWidget);
      expect(find.textContaining('FACT OF THE DAY'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('assets/facts/facts.json', () {
    final raw = jsonDecode(
      File('assets/facts/facts.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final entries = (raw['facts'] as List).cast<Map<String, dynamic>>();

    test('has a version and at least one fact', () {
      expect(raw['version'], 1);
      expect(entries, isNotEmpty);
    });

    test('ids are fdNNN and unique', () {
      final ids = [for (final e in entries) e['id']];
      for (final id in ids) {
        expect(id, matches(RegExp(r'^fd\d{3,}$')));
      }
      expect(ids.toSet().length, ids.length, reason: 'duplicate id');
    });

    test('every fact has the required fields', () {
      for (final e in entries) {
        expect(e['title_id'], isA<String>(), reason: '${e['id']} title_id');
        expect(e['title_id'] as String, matches(RegExp(r'^[a-z0-9-]+$')));
        expect(e['text'], isA<String>(), reason: '${e['id']} text');
        expect((e['text'] as String).trim(), isNotEmpty);
      }
      expect(
        parseFacts(File('assets/facts/facts.json').readAsStringSync()),
        hasLength(entries.length),
      );
    });

    test('text is 25 words or fewer and 160 characters or fewer', () {
      for (final e in entries) {
        final text = (e['text'] as String).trim();
        final words = text.split(RegExp(r'\s+')).length;
        expect(words, lessThanOrEqualTo(25), reason: '${e['id']}: $text');
        expect(text.length, lessThanOrEqualTo(160), reason: '${e['id']}');
        expect(text, isNot(contains('http')), reason: '${e['id']} link');
      }
    });
  });
}
