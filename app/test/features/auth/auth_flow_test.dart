// S18: sign-in is required. Welcome, Sign in, Create account, Forgot
// password, Settings > Account (sign out, delete) and the session ending
// on a rejected refresh. No email verification (D48). FakeAuthBackend, no
// network.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/app/router.dart';
import 'package:maximus/data/api/auth_tokens.dart';
import 'package:maximus/features/auth/auth_redirect.dart';
import 'package:maximus/core/widgets/widgets.dart';
import 'package:maximus/data/db/app_database.dart';
import 'package:maximus/features/settings/voices.dart';

import '../../app_harness.dart';
import '../../fakes/fake_auth.dart';
import '../../helpers.dart';

List<Override> get _voices => [
  ttsVoicesProvider.overrideWith((_) async => const <TtsVoice>[]),
];

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await AppHarness.settle(tester);
}

/// Waits out Welcome (1.5 s) and lands on Sign in.
Future<void> _toSignIn(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1600));
  await AppHarness.settle(tester);
  expect(find.text('Welcome back'), findsOneWidget);
}

Future<void> _type(WidgetTester tester, String hint, String text) async {
  final f = find.widgetWithText(TextField, hint);
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> _openSettings(WidgetTester tester) =>
    _tap(tester, find.bySemanticsLabel('Settings'));

Finder get _home => find.bySemanticsLabel('Home');
bool _createEnabled(WidgetTester tester) {
  final b = tester.widget<PrimaryButton>(
    find.widgetWithText(PrimaryButton, 'Create account'),
  );
  return b.onPressed != null;
}

void main() {
  testWidgets('signed out: Welcome, then Sign in; no Apple button', (
    tester,
  ) async {
    usePixel8(tester);
    await AppHarness.pump(tester, signedIn: false, overrides: _voices);
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    await _toSignIn(tester);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or with email'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('Apple'), findsNothing);
    expect(_home, findsNothing, reason: 'no tabs while signed out');
  });

  testWidgets('email sign-in goes Home; tokens only in secure storage', (
    tester,
  ) async {
    usePixel8(tester);
    final backend = FakeAuthBackend()
      ..addUser(AppHarness.email, password: AppHarness.password);
    final h = await AppHarness.pump(
      tester,
      signedIn: false,
      backend: backend,
      overrides: _voices,
    );
    await _toSignIn(tester);
    await _type(tester, 'Email', '  Ada@Example.com ');
    await _type(tester, 'Password', AppHarness.password);
    await _tap(tester, find.text('Sign in'));
    expect(backend.calls, contains('POST /v1/auth/signin'));
    expect(_home, findsWidgets);
    expect(find.text('Welcome back'), findsNothing);

    final refresh = h.store.values[TokenKeys.refreshToken];
    expect(refresh, isNotNull);
    expect(h.store.values[TokenKeys.userEmail], AppHarness.email);
    // Nothing secret in drift.
    final settings = await AppHarness.run(tester, h.db.settingsDao.readAll);
    expect(settings.values, isNot(contains(refresh)));
    expect(settings.keys.where((k) => k.contains('token')), isEmpty);
  });

  testWidgets('wrong password: friendly message, still on Sign in', (
    tester,
  ) async {
    usePixel8(tester);
    final backend = FakeAuthBackend()..addUser(AppHarness.email);
    final h = await AppHarness.pump(
      tester,
      signedIn: false,
      backend: backend,
      overrides: _voices,
    );
    await _toSignIn(tester);
    await _type(tester, 'Email', AppHarness.email);
    await _type(tester, 'Password', 'not my password');
    await _tap(tester, find.text('Sign in'));
    expect(find.text('Wrong email or password'), findsOneWidget);
    expect(find.text('server text the app never shows'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(h.store.values, isEmpty);

    // Empty fields are caught before any call.
    backend.calls.clear();
    await _type(tester, 'Password', '');
    await _tap(tester, find.text('Sign in'));
    expect(find.text('Wrong email or password'), findsOneWidget);
    expect(backend.calls, isEmpty);
  });

  testWidgets('sign-up: confirm mismatch blocks submit, then signs in', (
    tester,
  ) async {
    usePixel8(tester);
    final backend = FakeAuthBackend()
      ..addUser('grace@example.com', password: null, google: true);
    await AppHarness.pump(
      tester,
      signedIn: false,
      backend: backend,
      overrides: _voices,
    );
    await _toSignIn(tester);
    await _tap(tester, find.text('Create an account'));
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.widgetWithText(TextField, 'Your name'), findsNothing);
    expect(find.text('10 to 128 characters'), findsOneWidget);
    expect(_createEnabled(tester), isFalse);

    await _type(tester, 'Email', 'lin@example.com');
    await _type(tester, 'Password', 'short');
    await _type(tester, 'Confirm password', 'short');
    expect(_createEnabled(tester), isFalse, reason: 'rule not met');

    await _type(tester, 'Password', 'long enough pass');
    expect(find.text("Passwords don't match"), findsOneWidget);
    expect(_createEnabled(tester), isFalse, reason: 'mismatch');
    await _tap(tester, find.text('Create account'));
    expect(backend.calls, isEmpty);

    await _type(tester, 'Confirm password', 'long enough pass');
    expect(find.text("Passwords don't match"), findsNothing);
    expect(_createEnabled(tester), isTrue);

    // A Google-only email says so.
    await _type(tester, 'Email', 'grace@example.com');
    await _tap(tester, find.text('Create account'));
    expect(
      find.text('This email signs in with Google. Use Continue with Google.'),
      findsOneWidget,
    );
    expect(backend.calls, ['POST /v1/auth/signup']);

    backend.calls.clear();
    await _type(tester, 'Email', 'lin@example.com');
    await _tap(tester, find.text('Create account'));
    expect(backend.calls, ['POST /v1/auth/signup'], reason: 'submits once');
    expect(_home, findsWidgets, reason: 'signed in at once, no verify step');
    expect(find.text('Check your email'), findsNothing);
    expect(backend.users.containsKey('lin@example.com'), isTrue);
  });

  testWidgets('sign-up: mismatch shows once the confirm field loses focus', (
    tester,
  ) async {
    usePixel8(tester);
    await AppHarness.pump(tester, signedIn: false, overrides: _voices);
    await _toSignIn(tester);
    await _tap(tester, find.text('Create an account'));
    await _type(tester, 'Password', 'long enough pass');
    await tester.tap(find.widgetWithText(TextField, 'Confirm password'));
    await tester.pump();
    expect(find.text("Passwords don't match"), findsNothing);
    await tester.tap(find.widgetWithText(TextField, 'Email'));
    await tester.pump();
    expect(find.text("Passwords don't match"), findsOneWidget);
  });

  test('no verify-email route exists', () {
    for (final r in AppRoute.values) {
      expect(r.path, isNot(contains('verify')), reason: r.name);
    }
    expect(AuthPaths.signedOut, isNot(contains('/verify-email')));
  });

  testWidgets('Google: one tap signs in; closing the picker stays put', (
    tester,
  ) async {
    usePixel8(tester);
    final google = FakeGoogleAuth();
    final backend = FakeAuthBackend();
    final h = await AppHarness.pump(
      tester,
      signedIn: false,
      backend: backend,
      google: google,
      overrides: _voices,
    );
    await _toSignIn(tester);

    google.pick = () => null;
    await _tap(tester, find.text('Continue with Google'));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(backend.calls, isEmpty);

    google.pick = () => 'google-id-token';
    await _tap(tester, find.text('Continue with Google'));
    expect(backend.calls, ['POST /v1/auth/google']);
    expect(_home, findsWidgets);
    expect(h.store.values[TokenKeys.userEmail], 'grace@example.com');
  });

  testWidgets('no GOOGLE_CLIENT_ID: button disabled with a note', (
    tester,
  ) async {
    usePixel8(tester);
    final backend = FakeAuthBackend();
    await AppHarness.pump(
      tester,
      signedIn: false,
      backend: backend,
      google: FakeGoogleAuth(available: false),
      overrides: _voices,
    );
    await _toSignIn(tester);
    expect(
      find.text(
        'Google sign-in is not set up in this build. Use email for now.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue with Google'), warnIfMissed: false);
    await AppHarness.settle(tester);
    expect(backend.calls, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('forgot password: email, then Check your email', (tester) async {
    usePixel8(tester);
    final backend = FakeAuthBackend();
    await AppHarness.pump(
      tester,
      signedIn: false,
      backend: backend,
      overrides: _voices,
    );
    await _toSignIn(tester);
    await _tap(tester, find.text('Forgot password?'));
    expect(find.text('Reset your password'), findsOneWidget);
    await _type(tester, 'Email', 'nobody@example.com');
    await _tap(tester, find.text('Send the link'));
    expect(backend.calls, ['POST /v1/auth/forgot-password']);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('nobody@example.com'), findsOneWidget);
    await _tap(tester, find.text('Back to sign in'));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('sign out: confirm, wipe local data, back to Welcome', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    final refresh = h.store.values[TokenKeys.refreshToken]!;
    await _openSettings(tester);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text(AppHarness.email), findsOneWidget);

    await _tap(tester, find.text('Sign out'));
    expect(find.text('Sign out?'), findsOneWidget);
    await _tap(tester, find.text('Stay signed in'));
    expect(h.store.values, isNotEmpty);

    await _tap(tester, find.text('Sign out'));
    await _tap(tester, find.widgetWithText(PrimaryButton, 'Sign out'));
    expect(h.backend.calls, contains('POST /v1/auth/signout'));
    expect(h.store.values, isEmpty);
    expect(h.google.signOuts, 1);
    // The Settings refresh rotated the stored token; both are dead now.
    expect(h.backend.isLiveRefresh(refresh), isFalse);
    final study = await AppHarness.run(
      tester,
      () => h.db.select(h.db.studyList).get(),
    );
    expect(study, isEmpty);
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
    await _toSignIn(tester);
  });

  testWidgets('delete my account: password, DELETE /v1/me, wiped', (
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
    expect(find.text('Delete your account?'), findsOneWidget);

    await _type(tester, 'Password', 'wrong one');
    await _tap(tester, find.widgetWithText(MxPressable, 'Delete my account'));
    expect(find.text('Wrong password. Try again.'), findsOneWidget);
    expect(h.backend.users, contains(AppHarness.email));

    await _type(tester, 'Password', AppHarness.password);
    await _tap(tester, find.widgetWithText(MxPressable, 'Delete my account'));
    expect(h.backend.calls, contains('DELETE /v1/me'));
    expect(h.backend.users, isNot(contains(AppHarness.email)));
    expect(h.store.values, isEmpty);
    final study = await AppHarness.run(
      tester,
      () => h.db.select(h.db.studyList).get(),
    );
    expect(study, isEmpty);
    expect(find.text('Delete your account?'), findsNothing);
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
  });

  testWidgets('Google-only account deletes with a fresh token, no password', (
    tester,
  ) async {
    usePixel8(tester);
    final backend = FakeAuthBackend()
      ..addUser(AppHarness.email, password: null, google: true);
    final h = await AppHarness.pump(
      tester,
      backend: backend,
      overrides: _voices,
    );
    await _openSettings(tester);
    await _tap(tester, find.text('Delete my account'));
    expect(find.widgetWithText(TextField, 'Password'), findsNothing);
    backend.calls.clear();
    await _tap(tester, find.widgetWithText(MxPressable, 'Delete my account'));
    expect(backend.calls, ['POST /v1/auth/refresh', 'DELETE /v1/me']);
    expect(h.store.values, isEmpty);
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
  });

  testWidgets('rejected refresh signs out cleanly, keeps local data', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await AppHarness.run(
      tester,
      () => h.db.userStateDao.addToStudyList('roman-history'),
    );
    expect(_home, findsWidgets);
    h.backend.refreshFailure = (401, 'token_reused');
    // Settings asks /v1/me, which needs a token, which needs a refresh.
    await _openSettings(tester);
    expect(h.store.values, isEmpty);
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
    final study = await AppHarness.run(
      tester,
      () => h.db.select(h.db.studyList).get(),
    );
    expect(study, hasLength(1), reason: 'CONTRACTS 14.5: keep the drift data');
  });

  testWidgets('opening Settings (a /v1/me refresh) stays on Settings', (
    tester,
  ) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await _tap(tester, find.bySemanticsLabel('Library'));
    await _tap(tester, find.bySemanticsLabel('Home'));
    // Opening Settings asks /v1/me, which updates the signed-in user.
    await _openSettings(tester);
    expect(h.backend.calls, contains('GET /v1/me'));
    await AppHarness.settle(tester);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
  });

  testWidgets('Settings shows no verification banner', (tester) async {
    usePixel8(tester);
    final h = await AppHarness.pump(tester, overrides: _voices);
    await _openSettings(tester);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Confirm your email'), findsNothing);
    expect(find.text('Resend'), findsNothing);
    expect(
      h.backend.calls.where((c) => c.contains('verif')),
      isEmpty,
      reason: 'no resend-verification call',
    );
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('sign-in screens lay out in $theme on a small phone', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(720, 1280); // 360 x 640 dp
      addTearDown(tester.view.reset);
      final db = AppDatabase(NativeDatabase.memory());
      await AppHarness.run(tester, () => db.settingsDao.write('theme', theme));
      await AppHarness.pump(
        tester,
        db: db,
        signedIn: false,
        google: FakeGoogleAuth(available: false),
        overrides: _voices,
      );
      await _toSignIn(tester);
      await _tap(tester, find.text('Create an account'));
      expect(find.text('Create your account'), findsOneWidget);
      await _tap(tester, find.text('Sign in'));
      await _tap(tester, find.text('Forgot password?'));
      expect(find.text('Reset your password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
