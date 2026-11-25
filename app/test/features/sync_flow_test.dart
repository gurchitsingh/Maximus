// S15 in the whole app: Settings "Sync now", sign-out pushes before it
// wipes (and warns offline), sign out and back in brings the data back,
// account deletion never wipes on failure. FakeAuthBackend, no network.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/widgets/widgets.dart';
import 'package:maximus/data/api/auth_tokens.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/data/sync/sync_record.dart';
import 'package:maximus/features/settings/voices.dart';

import '../app_harness.dart';
import '../helpers.dart';

List<Override> get _voices => [
  ttsVoicesProvider.overrideWith((_) async => const <TtsVoice>[]),
];

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await AppHarness.settle(tester);
}

Future<void> _openSettings(WidgetTester tester) =>
    _tap(tester, find.bySemanticsLabel('Settings'));

Future<void> _type(WidgetTester tester, String hint, String text) async {
  final f = find.widgetWithText(TextField, hint);
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<List<StudyItemRow>> _study(WidgetTester tester, AppHarness h) =>
    AppHarness.run(
      tester,
      () => (h.db.select(
        h.db.studyList,
      )..where((t) => t.deleted.equals(false))).get(),
    );

String _userId(AppHarness h) => h.backend.users[AppHarness.email]!.id;

void main() {
  testWidgets('Settings: Sync now pushes and shows the last-synced time', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await AppHarness.run(tester, () => h.db.userStateDao.setRating('chanakya', 1));
    await _openSettings(tester);
    expect(find.text('Not synced yet'), findsOneWidget);

    await _tap(tester, find.text('Sync now'));
    expect(find.text('Last synced just now'), findsOneWidget);
    expect(
      h.backend.sync.live(_userId(h), SyncKind.rating).single.id,
      'chanakya',
    );
  });

  testWidgets('Settings: Sync now offline says so, quietly', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await _openSettings(tester);
    h.backend.offline = true;
    await _tap(tester, find.text('Sync now'));
    expect(find.text('Offline. Will sync later'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a local change syncs 5 s later on its own', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices, sync: true);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(h.backend.sync.live(_userId(h), SyncKind.studyItem), isEmpty);
    await tester.pump(const Duration(seconds: 3));
    await AppHarness.settle(tester);
    expect(
      h.backend.sync.live(_userId(h), SyncKind.studyItem).single.id,
      'roman-history',
    );
  });

  testWidgets('sign out online: unsynced changes are pushed, then wiped', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await AppHarness.run(tester, () async {
      await h.db.userStateDao.setRating('chanakya', -1);
      await h.db.userStateDao.addToStudyList('roman-history');
    });
    await _openSettings(tester);
    await _tap(tester, find.text('Sign out'));
    expect(find.textContaining('saved to your account'), findsOneWidget);
    await _tap(tester, find.widgetWithText(PrimaryButton, 'Sign out'));

    final calls = h.backend.calls;
    expect(
      calls.indexOf('POST /v1/me/sync'),
      lessThan(calls.indexOf('POST /v1/auth/signout')),
      reason: 'push before the wipe',
    );
    final uid = _userId(h);
    expect(h.backend.sync.live(uid, SyncKind.rating).single.id, 'chanakya');
    expect(h.backend.sync.live(uid, SyncKind.studyItem), hasLength(1));
    expect(await _study(tester, h), isEmpty);
    expect(h.store.values, isEmpty);
  });

  testWidgets('sign out offline with unsynced changes: the confirm names '
      'them; Stay keeps everything, Sign out anyway wipes', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await AppHarness.run(tester, () async {
      await h.db.userStateDao.setRating('chanakya', -1);
      await h.db.userStateDao.addToStudyList('roman-history');
    });
    await _openSettings(tester);
    h.backend.offline = true;

    await _tap(tester, find.text('Sign out'));
    expect(
      find.textContaining('2 changes not synced yet will be lost'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Stay signed in'));
    expect(await _study(tester, h), hasLength(1));
    expect(h.store.values, contains(TokenKeys.refreshToken));

    await _tap(tester, find.text('Sign out'));
    await _tap(tester, find.widgetWithText(PrimaryButton, 'Sign out anyway'));
    expect(await _study(tester, h), isEmpty);
    expect(h.store.values, isEmpty);
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
  });

  testWidgets('sign out and back in: the data comes back from the account', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices, sync: true);
    await AppHarness.run(tester, () async {
      await h.db.userStateDao.setRating('chanakya', 1);
      await h.db.userStateDao.addToStudyList('roman-history');
      await h.db.settingsDao.write(SettingKeys.textSize, 'large');
    });
    await _openSettings(tester);
    await _tap(tester, find.text('Sign out'));
    await _tap(tester, find.widgetWithText(PrimaryButton, 'Sign out'));
    expect(await _study(tester, h), isEmpty);
    expect(
      await AppHarness.run(
        tester,
        () => h.db.settingsDao.read(SettingKeys.textSize),
      ),
      'medium',
    );

    await tester.pump(const Duration(milliseconds: 1600)); // Welcome
    await AppHarness.settle(tester);
    await _type(tester, 'Email', AppHarness.email);
    await _type(tester, 'Password', AppHarness.password);
    await _tap(tester, find.text('Sign in'));
    await AppHarness.settle(tester);

    expect((await _study(tester, h)).single.titleId, 'roman-history');
    final ratings = await AppHarness.run(
      tester,
      () => (h.db.select(
        h.db.ratings,
      )..where((t) => t.deleted.equals(false))).get(),
    );
    expect(ratings.single.value, 1);
    expect(
      await AppHarness.run(
        tester,
        () => h.db.settingsDao.read(SettingKeys.textSize),
      ),
      'large',
    );
  });

  testWidgets('delete my account offline: an error, and nothing is wiped', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    await _openSettings(tester);
    await _tap(tester, find.text('Delete my account'));
    await _type(tester, 'Password', AppHarness.password);
    h.backend.offline = true;
    await _tap(tester, find.widgetWithText(MxPressable, 'Delete my account'));

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('You are offline'), findsOneWidget);
    expect(h.backend.users, contains(AppHarness.email));
    expect(await _study(tester, h), hasLength(1));
    expect(h.store.values, contains(TokenKeys.refreshToken));
  });

  testWidgets('delete my account: success is confirmed', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await _openSettings(tester);
    await _tap(tester, find.text('Delete my account'));
    await _type(tester, 'Password', AppHarness.password);
    await _tap(tester, find.widgetWithText(MxPressable, 'Delete my account'));
    expect(find.text('Your account and data are deleted.'), findsOneWidget);
    expect(h.store.values, isEmpty);
  });
}
