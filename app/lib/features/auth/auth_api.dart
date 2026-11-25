// /v1/auth/* and /v1/me calls (CONTRACTS 14.1, 17). Errors arrive as
// ApiException with the server's code; auth_messages.dart turns them into
// copy.
import '../../data/api/api_client.dart';
import '../../data/api/auth_tokens.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi(this.client);

  final ApiClient client;

  Future<TokenGrant> signIn(String email, String password) async =>
      TokenGrant.fromJson(
        await client.send(
              'POST',
              '/v1/auth/signin',
              body: {'email': email, 'password': password},
            ) ??
            const {},
      );

  Future<TokenGrant> signUp(
    String email,
    String password, {
    String? displayName,
  }) async => TokenGrant.fromJson(
    await client.send(
          'POST',
          '/v1/auth/signup',
          body: {
            'email': email,
            'password': password,
            'display_name': ?displayName,
          },
        ) ??
        const {},
  );

  Future<TokenGrant> google(String idToken) async => TokenGrant.fromJson(
    await client.send('POST', '/v1/auth/google', body: {'id_token': idToken}) ??
        const {},
  );

  /// Idempotent on the server: an unknown token is still 204.
  Future<void> signOut(String refreshToken) => client.send(
    'POST',
    '/v1/auth/signout',
    body: {'refresh_token': refreshToken},
  );

  /// Always 202, whether or not the email has an account.
  Future<void> forgotPassword(String email) =>
      client.send('POST', '/v1/auth/forgot-password', body: {'email': email});

  Future<AuthUser> me() async =>
      AuthUser.fromJson((await client.send('GET', '/v1/me')) ?? const {});

  /// Email accounts send [password]; Google accounts need a fresh token.
  Future<void> deleteMe({String? password}) => client.send(
    'DELETE',
    '/v1/me',
    body: password == null ? null : {'password': password},
  );
}
