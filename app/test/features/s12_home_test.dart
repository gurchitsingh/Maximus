// S12 on Home: On This Day placed (CONTRACTS 2.7), first run offline or a
// server error (3.6), and an empty catalogue (no crash, empty state).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/api/api_error.dart';
import 'package:maximus/data/repositories/content_source.dart';
import 'package:maximus/data/repositories/on_this_day_repository.dart';
import 'package:maximus/features/on_this_day/on_this_day_card.dart';

import '../app_harness.dart';
import '../helpers.dart';

/// The sample On This Day, re-dated to today so the card shows.
class _TodayOtd implements OnThisDaySource {
  @override
  Future<String> onThisDayJson(String mmdd) {
    final j = jsonDecode(
      File('assets/dev/on-this-day.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return Future.value(jsonEncode(j..['date'] = mmdd));
  }
}

class _OfflineOtd implements OnThisDaySource {
  @override
  Future<String> onThisDayJson(String mmdd) =>
      Future.error(const ApiException(code: ApiException.offline));
}

class _FailingSource implements ContentSource {
  _FailingSource(this.error);
  final ApiException error;

  @override
  Future<String> catalogueJson() => Future.error(error);

  @override
  Future<String> titleJson(String id) => Future.error(error);
}

/// A served catalogue with no titles (nothing published yet).
class _EmptySource implements ContentSource {
  @override
  Future<String> catalogueJson() {
    final j = jsonDecode(
      File('assets/dev/catalogue.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    j
      ..['featured_id'] = null
      ..['onboarding_leader_ids'] = <String>[]
      ..['titles'] = <Object>[]
      ..['images'] = <Object>[];
    return Future.value(jsonEncode(j));
  }

  @override
  Future<String> titleJson(String id) => Future.error(TitleNotFound(id));
}

void main() {
  testWidgets('Home shows On This Day under the quiz scores', (tester) async {
    usePixel8(tester);
    await AppHarness.pump(
      tester,
      overrides: [onThisDaySourceProvider.overrideWithValue(_TodayOtd())],
    );
    expect(find.text('Your quiz scores'), findsOneWidget);
    expect(find.text(onThisDayKicker(DateTime.now())), findsOneWidget);
    // The first linked item is featured (2.7).
    expect(find.text('44 BCE · Roman Republic'), findsOneWidget);
    expect(find.text('From Wikipedia · CC BY-SA 4.0'), findsOneWidget);
    final scores = tester.getTopLeft(find.text('Your quiz scores')).dy;
    final otd = tester.getTopLeft(find.text('44 BCE · Roman Republic')).dy;
    expect(otd, greaterThan(scores));
  });

  testWidgets('Home hides On This Day when offline with no copy', (
    tester,
  ) async {
    usePixel8(tester);
    await AppHarness.pump(
      tester,
      overrides: [onThisDaySourceProvider.overrideWithValue(_OfflineOtd())],
    );
    expect(find.text('Your quiz scores'), findsOneWidget);
    expect(find.textContaining('ON THIS DAY'), findsNothing);
  });

  testWidgets('first run offline: connect to set up, with retry', (
    tester,
  ) async {
    usePixel8(tester);
    await AppHarness.pump(
      tester,
      contentSource: _FailingSource(
        const ApiException(code: ApiException.offline),
      ),
    );
    expect(find.text('Could not load the library'), findsOneWidget);
    expect(find.text('Connect to the internet to set up Maximus.'), findsOne);
    await tester.tap(find.text('Try again'));
    await AppHarness.settle(tester);
    expect(find.text('Could not load the library'), findsOneWidget);
  });

  testWidgets('first run, server error: generic wording', (tester) async {
    usePixel8(tester);
    await AppHarness.pump(
      tester,
      contentSource: _FailingSource(
        const ApiException(code: 'internal_error', status: 500),
      ),
    );
    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(
      find.text('Connect to the internet to set up Maximus.'),
      findsNothing,
    );
  });

  testWidgets('empty catalogue: empty state on Home and Library', (
    tester,
  ) async {
    usePixel8(tester);
    await AppHarness.pump(tester, contentSource: _EmptySource());
    expect(tester.takeException(), isNull);
    expect(find.text('The library is empty'), findsOneWidget);
    await tester.tap(find.text('Library'));
    await AppHarness.settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('The library is empty'), findsOneWidget);
  });
}
