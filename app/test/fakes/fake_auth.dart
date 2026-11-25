// In-memory stand-ins for the auth server (CONTRACTS 14), secure storage
// and Google sign-in. No real network: FakeAuthBackend is a dio adapter.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:maximus/data/api/api_client.dart';
import 'package:maximus/data/api/auth_tokens.dart';
import 'package:maximus/features/auth/google_auth.dart';

import 'fake_sync.dart';

class FakeUser {
  FakeUser({
    required this.id,
    required this.email,
    this.password,
    this.google = false,
    this.verified = false,
    this.name,
  });

  final String id;
  final String email;
  String? password;
  bool google;
  bool verified;
  String? name;

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'email_verified': verified,
    'display_name': name,
    'has_password': password != null,
    'has_google': google,
    'created_at': '2026-11-25T10:00:00Z',
  };
}

class FakeAuthBackend implements HttpClientAdapter {
  final users = <String, FakeUser>{}; // by email
  final _refresh = <String, String>{}; // live refresh token -> email
  final _revoked = <String>{};
  final _access = <String, String>{}; // live access token -> email
  final _expired = <String>{};
  int _n = 0;

  /// Every call as "METHOD /path", in order.
  final calls = <String>[];

  /// The Authorization header of each call (null when absent).
  final authHeaders = <String, String?>{};

  bool offline = false;

  /// /v1/me/sync (S15), keyed by user id.
  final sync = FakeSyncServer();

  /// Answers any refresh with this status and code (simulated server
  /// trouble), when set.
  (int, String)? refreshFailure;

  /// The email Google's fake ID token stands for.
  String googleEmail = 'grace@example.com';

  FakeUser addUser(
    String email, {
    String? password = 'correct horse battery',
    bool google = false,
    bool verified = true,
    String? name,
  }) => users[email] = FakeUser(
    id: 'u-${++_n}',
    email: email,
    password: password,
    google: google,
    verified: verified,
    name: name,
  );

  /// A signed-in session for [email]: returns the refresh token.
  String issueRefresh(String email) {
    final t = 'rt-${++_n}';
    _refresh[t] = email;
    return t;
  }

  /// Every live access token becomes expired (token_expired on use).
  void expireAccessTokens() {
    _expired.addAll(_access.keys);
    _access.clear();
  }

  bool isLiveRefresh(String token) => _refresh.containsKey(token);
  bool isRevoked(String token) => _revoked.contains(token);
  int count(String call) => calls.where((c) => c == call).length;

  Map<String, Object?> _grant(FakeUser u) {
    final access = 'at-${++_n}';
    _access[access] = u.email;
    return {
      'user': u.toJson(),
      'access_token': access,
      'refresh_token': issueRefresh(u.email),
      'expires_in': 900,
    };
  }

  ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
    body == null ? '' : jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  ResponseBody _error(int status, String code, {Map<String, Object?>? d}) =>
      _json(status, {
        'error': {
          'code': code,
          'message': 'server text the app never shows',
          'retry_after_s': null,
          'details': d,
        },
      });

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final call = '${o.method} ${o.uri.path}';
    calls.add(call);
    authHeaders[call] = o.headers['Authorization'] as String?;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline (fake)',
      );
    }
    Map<String, dynamic> body = const {};
    if (requestStream != null) {
      final bytes = await requestStream.expand((b) => b).toList();
      if (bytes.isNotEmpty) {
        body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
    }
    if (o.uri.path == '/v1/me/sync') {
      final gate = sync.gate;
      if (gate != null) await gate;
      if (offline) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline (fake)',
        );
      }
    }
    return _route(call, o, body);
  }

  FakeUser? _bearer(RequestOptions o, void Function(ResponseBody) fail) {
    final h = o.headers['Authorization'] as String?;
    final token = h?.startsWith('Bearer ') == true ? h!.substring(7) : null;
    if (token != null && _expired.contains(token)) {
      fail(_error(401, 'token_expired'));
      return null;
    }
    final email = token == null ? null : _access[token];
    final user = email == null ? null : users[email];
    if (user == null) fail(_error(401, 'unauthorized'));
    return user;
  }

  ResponseBody _route(String call, RequestOptions o, Map<String, dynamic> b) {
    ResponseBody? failed;
    void fail(ResponseBody r) => failed = r;
    switch (call) {
      case 'POST /v1/auth/signup':
        final email = (b['email'] as String).trim().toLowerCase();
        final pw = b['password'] as String;
        if (pw.length < 10 || pw.length > 128) {
          return _error(422, 'weak_password');
        }
        final existing = users[email];
        if (existing != null) {
          return _error(
            409,
            'email_taken',
            d: existing.password == null ? {'method': 'google'} : null,
          );
        }
        final u = addUser(
          email,
          password: pw,
          verified: false,
          name: b['display_name'] as String?,
        );
        return _json(201, _grant(u));
      case 'POST /v1/auth/signin':
        final u = users[(b['email'] as String).trim().toLowerCase()];
        if (u == null || u.password == null || u.password != b['password']) {
          return _error(401, 'invalid_credentials');
        }
        return _json(200, _grant(u));
      case 'POST /v1/auth/google':
        if (b['id_token'] != 'google-id-token') {
          return _error(401, 'google_token_invalid');
        }
        final u =
            users[googleEmail] ??
            addUser(googleEmail, password: null, verified: true);
        u.google = true;
        return _json(200, _grant(u));
      case 'POST /v1/auth/refresh':
        final t = b['refresh_token'] as String;
        if (refreshFailure case (final status, final code)) {
          return _error(status, code);
        }
        if (_revoked.contains(t)) {
          // Reuse detection: revoke the whole family.
          final email = _revokedOwner[t];
          _refresh.removeWhere((_, e) => e == email);
          return _error(401, 'token_reused');
        }
        final email = _refresh.remove(t);
        if (email == null || users[email] == null) {
          return _error(401, 'token_invalid');
        }
        _revoked.add(t);
        _revokedOwner[t] = email;
        return _json(200, _grant(users[email]!));
      case 'POST /v1/auth/signout':
        final t = b['refresh_token'] as String;
        final email = _refresh.remove(t);
        if (email != null) {
          _revoked.add(t);
          _revokedOwner[t] = email;
        }
        return _json(204, null);
      case 'POST /v1/auth/forgot-password':
        return _json(202, null);
      case 'POST /v1/auth/resend-verification':
        return _bearer(o, fail) == null ? failed! : _json(202, null);
      case 'GET /v1/me':
        final u = _bearer(o, fail);
        return u == null ? failed! : _json(200, u.toJson());
      case 'DELETE /v1/me':
        final u = _bearer(o, fail);
        if (u == null) return failed!;
        final pw = b['password'] as String?;
        if (pw != null && pw != u.password) {
          return _error(401, 'invalid_credentials');
        }
        if (pw == null && u.password != null && !u.google) {
          return _error(403, 'reauth_required');
        }
        users.remove(u.email);
        _refresh.removeWhere((_, e) => e == u.email);
        _access.removeWhere((_, e) => e == u.email);
        return _json(204, null);
      case 'GET /v1/me/sync' || 'POST /v1/me/sync':
        final u = _bearer(o, fail);
        if (u == null) return failed!;
        if (sync.failures.isNotEmpty) {
          final (status, code) = sync.failures.removeAt(0);
          return _error(status, code);
        }
        if (call.startsWith('GET')) {
          if (sync.failPulls) return _error(500, 'internal_error');
          final q = o.uri.queryParameters;
          return _json(
            200,
            sync.pull(
              u.id,
              int.parse(q['since'] ?? '0'),
              int.parse(q['limit'] ?? '200'),
            ),
          );
        }
        return _json(200, sync.push(u.id, b['records'] as List<dynamic>));
      case 'GET /v1/catalogue':
        return _json(200, {'titles': <Object>[]});
    }
    return _error(404, 'not_found');
  }

  final _revokedOwner = <String, String>{};

  @override
  void close({bool force = false}) {}
}

/// An ApiClient whose requests go to [backend], with bearer handling.
ApiClient fakeApiClient(FakeAuthBackend backend, AuthTokens? tokens) =>
    ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://fake.test'))
        ..httpClientAdapter = backend,
      auth: tokens,
    );

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> clear() async => values.clear();
}

class FakeGoogleAuth implements GoogleAuth {
  FakeGoogleAuth({this.available = true});

  @override
  bool available;

  /// What the picker returns: the token, null (closed), or throws.
  String? Function() pick = () => 'google-id-token';
  int signOuts = 0;

  @override
  Future<String?> idToken() async => pick();

  @override
  Future<void> signOut() async => signOuts++;
}
