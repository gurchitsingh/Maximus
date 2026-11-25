// Bearer tokens for /v1 (CONTRACTS 14.2, 14.5). The access token lives in
// memory only. The refresh token and the signed-in user's id, email and name
// live in flutter_secure_storage: never in drift, prefs or logs.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'api_error.dart';

/// Secure storage keys (14.5).
abstract final class TokenKeys {
  static const refreshToken = 'refresh_token';
  static const userId = 'user_id';
  static const userEmail = 'user_email';
  static const userName = 'user_name';

  static const all = [refreshToken, userId, userEmail, userName];
}

/// Where the refresh token and the user's id, email and name are kept.
abstract class TokenStore {
  Future<String?> read(String key);

  /// Writes [value]; null deletes the key.
  Future<void> write(String key, String? value);

  /// Deletes every [TokenKeys] key (and nothing else).
  Future<void> clear();
}

/// The real store: Android Keystore-backed storage.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String? value) =>
      value == null ? _s.delete(key: key) : _s.write(key: key, value: value);

  @override
  Future<void> clear() async {
    for (final k in TokenKeys.all) {
      await _s.delete(key: k);
    }
  }
}

/// The token pair and user JSON from an `AuthResult` (14.1).
class TokenGrant {
  const TokenGrant({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory TokenGrant.fromJson(Map<String, dynamic> json) {
    final access = json['access_token'], refresh = json['refresh_token'];
    final user = json['user'];
    if (access is! String || refresh is! String || user is! Map) {
      throw const ApiException(
        code: ApiException.badResponse,
        message: 'AuthResult without tokens',
      );
    }
    return TokenGrant(
      accessToken: access,
      refreshToken: refresh,
      user: user.cast<String, dynamic>(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
}

/// Holds the session's tokens and runs the refresh (rotation, 14.2).
class AuthTokens {
  AuthTokens(this.store);

  final TokenStore store;

  String? _access;
  Future<String?>? _inflight;
  final _ended = StreamController<void>.broadcast();

  /// The current access token, null until sign-in or the first refresh.
  String? get accessToken => _access;

  /// Fires when the server rejects the refresh token (expired, revoked or
  /// reused): the stored session is already cleared.
  Stream<void> get sessionEnded => _ended.stream;

  Future<bool> get hasSession async =>
      (await store.read(TokenKeys.refreshToken)) != null;

  /// Stores a new grant from sign-in, sign-up, Google or a refresh.
  Future<void> save(TokenGrant g) async {
    _access = g.accessToken;
    await store.write(TokenKeys.refreshToken, g.refreshToken);
    await saveUser(g.user);
  }

  /// Keeps the user's id, email and name for an offline cold start.
  Future<void> saveUser(Map<String, dynamic> user) async {
    await store.write(TokenKeys.userId, user['id'] as String?);
    await store.write(TokenKeys.userEmail, user['email'] as String?);
    await store.write(TokenKeys.userName, user['display_name'] as String?);
  }

  /// Forgets the session locally (memory and secure storage).
  Future<void> clear() async {
    _access = null;
    await store.clear();
  }

  /// Swaps the stored refresh token for a new pair. Single-flight: callers
  /// that arrive while a refresh runs share its result, so a rotated token
  /// is never presented twice (that would trip reuse detection).
  ///
  /// Returns the new access token, or null when there is no session or the
  /// server rejected the refresh token (the session is then cleared and
  /// [sessionEnded] fires). Offline and server errors are rethrown and keep
  /// the session: a device with a refresh token stays signed in (14.5).
  Future<String?> refresh(ApiClient client) {
    return _inflight ??= _refresh(client).whenComplete(() => _inflight = null);
  }

  Future<String?> _refresh(ApiClient client) async {
    final token = await store.read(TokenKeys.refreshToken);
    if (token == null) return null;
    try {
      final json = await client.send(
        'POST',
        '/v1/auth/refresh',
        body: {'refresh_token': token},
      );
      await save(TokenGrant.fromJson(json ?? const {}));
      return _access;
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
      await clear();
      _ended.add(null);
      return null;
    }
  }

  void dispose() => _ended.close();
}

/// Paths that never carry a bearer (14.5): auth itself and public content,
/// so a signed-out cold start can still load the catalogue.
bool needsBearer(String path) {
  if (!path.startsWith('/v1/')) return false;
  if (path.startsWith('/v1/auth/')) return false;
  if (path.startsWith('/v1/on-this-day')) return false;
  if (const {'/v1/catalogue', '/v1/feed', '/v1/credits'}.contains(path)) {
    return false;
  }
  // /v1/titles/{id} is public; /v1/titles/{id}/chat is not.
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.length == 3 && segments[1] == 'titles') return false;
  return true;
}

/// Adds `Authorization: Bearer` and, on a 401, refreshes once and retries
/// once (14.5). Installed by [ApiClient] when it is given [AuthTokens].
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.tokens, this.client, this.dio);

  final AuthTokens tokens;
  final ApiClient client;
  final Dio dio;

  static const _retried = 'mx_auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!needsBearer(options.uri.path)) return handler.next(options);
    var token = tokens.accessToken;
    if (token == null) {
      // Cold start: the access token is memory only, so get one first.
      try {
        token = await tokens.refresh(client);
      } on ApiException catch (e) {
        return handler.reject(DioException(requestOptions: options, error: e));
      }
    }
    if (token == null) {
      // No session (or it just ended): do not send a call that must fail.
      return handler.reject(
        DioException(
          requestOptions: options,
          error: const ApiException(code: 'unauthorized', status: 401),
        ),
      );
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final o = response.requestOptions;
    if (response.statusCode != 401 ||
        !needsBearer(o.uri.path) ||
        o.extra[_retried] == true) {
      return handler.next(response);
    }
    final used = o.headers['Authorization'];
    String? fresh;
    final current = tokens.accessToken;
    if (current != null && used != 'Bearer $current') {
      // Another call refreshed while this one was in flight.
      fresh = current;
    } else {
      try {
        fresh = await tokens.refresh(client);
      } on ApiException {
        return handler.next(response);
      }
    }
    if (fresh == null) return handler.next(response);
    o.extra[_retried] = true;
    o.headers['Authorization'] = 'Bearer $fresh';
    try {
      handler.next(await dio.fetch<dynamic>(o));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }
}
