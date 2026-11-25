// S18: bearer, refresh with rotation, one retry on 401, clean sign-out on a
// rejected refresh (CONTRACTS 14.2, 14.5). FakeAuthBackend, no network.
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/data/api/api_error.dart';
import 'package:maximus/data/api/auth_tokens.dart';

import '../fakes/fake_auth.dart';

void main() {
  late FakeAuthBackend backend;
  late MemoryTokenStore store;
  late AuthTokens tokens;
  late String seed;

  setUp(() {
    backend = FakeAuthBackend()..addUser('ada@example.com');
    seed = backend.issueRefresh('ada@example.com');
    store = MemoryTokenStore({TokenKeys.refreshToken: seed});
    tokens = AuthTokens(store);
  });

  tearDown(() => tokens.dispose());

  test('needsBearer: public content and auth stay public', () {
    for (final p in [
      '/v1/catalogue',
      '/v1/feed',
      '/v1/credits',
      '/v1/on-this-day',
      '/v1/titles/roman-history',
      '/v1/auth/signin',
      '/v1/auth/refresh',
      '/healthz',
      '/media/x.webp',
    ]) {
      expect(needsBearer(p), isFalse, reason: p);
    }
    for (final p in [
      '/v1/me',
      '/v1/me/sync',
      '/v1/me/chat/roman-history',
      '/v1/titles/roman-history/chat',
    ]) {
      expect(needsBearer(p), isTrue, reason: p);
    }
  });

  test('cold start: refreshes first, rotates, attaches the bearer', () async {
    final client = fakeApiClient(backend, tokens);
    final me = await client.send('GET', '/v1/me');
    expect(me?['email'], 'ada@example.com');
    expect(backend.calls, ['POST /v1/auth/refresh', 'GET /v1/me']);
    expect(backend.authHeaders['GET /v1/me'], 'Bearer ${tokens.accessToken}');
    // Rotation: the old refresh token is revoked, the new one is stored.
    final rotated = store.values[TokenKeys.refreshToken]!;
    expect(rotated, isNot(seed));
    expect(backend.isRevoked(seed), isTrue);
    expect(backend.isLiveRefresh(rotated), isTrue);
    // The access token is never written to storage.
    expect(store.values.values, isNot(contains(tokens.accessToken)));
  });

  test('no bearer on public calls', () async {
    final client = fakeApiClient(backend, tokens);
    await client.get('/v1/catalogue');
    expect(backend.calls, ['GET /v1/catalogue']);
    expect(backend.authHeaders['GET /v1/catalogue'], isNull);
  });

  test('token_expired: one refresh, one retry, then it works', () async {
    final client = fakeApiClient(backend, tokens);
    await client.send('GET', '/v1/me');
    backend.expireAccessTokens();
    backend.calls.clear();
    final me = await client.send('GET', '/v1/me');
    expect(me?['email'], 'ada@example.com');
    expect(backend.calls, [
      'GET /v1/me',
      'POST /v1/auth/refresh',
      'GET /v1/me',
    ]);
  });

  test('parallel 401s share a single refresh', () async {
    final client = fakeApiClient(backend, tokens);
    await client.send('GET', '/v1/me');
    backend.expireAccessTokens();
    backend.calls.clear();
    await Future.wait([
      client.send('GET', '/v1/me'),
      client.send('GET', '/v1/me'),
      client.send('GET', '/v1/me'),
    ]);
    expect(backend.count('POST /v1/auth/refresh'), 1);
    expect(backend.count('GET /v1/me'), 6);
  });

  test('a reused refresh token ends the session cleanly', () async {
    // Another device already rotated this token: the server sees reuse.
    final other = fakeApiClient(
      backend,
      AuthTokens(MemoryTokenStore({TokenKeys.refreshToken: seed})),
    );
    await other.send('GET', '/v1/me');
    store.values[TokenKeys.userEmail] = 'ada@example.com';

    var ended = 0;
    tokens.sessionEnded.listen((_) => ended++);
    final client = fakeApiClient(backend, tokens);
    await expectLater(
      client.send('GET', '/v1/me'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(ended, 1);
    expect(store.values, isEmpty, reason: 'refresh token and user cleared');
    expect(tokens.accessToken, isNull);
    expect(backend.count('GET /v1/me'), 1, reason: 'the other device only');
  });

  test('offline refresh keeps the session', () async {
    backend.offline = true;
    final client = fakeApiClient(backend, tokens);
    await expectLater(
      client.send('GET', '/v1/me'),
      throwsA(isA<ApiException>().having((e) => e.isOffline, 'offline', true)),
    );
    expect(store.values[TokenKeys.refreshToken], seed);
  });

  test('server trouble on refresh: no retry loop, session kept', () async {
    final client = fakeApiClient(backend, tokens);
    await client.send('GET', '/v1/me');
    final kept = store.values[TokenKeys.refreshToken];
    backend.expireAccessTokens();
    backend.refreshFailure = (500, 'internal_error');
    backend.calls.clear();
    await expectLater(
      client.send('GET', '/v1/me'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'token_expired'),
      ),
    );
    expect(backend.calls, ['GET /v1/me', 'POST /v1/auth/refresh']);
    expect(store.values[TokenKeys.refreshToken], kept);
  });
}
