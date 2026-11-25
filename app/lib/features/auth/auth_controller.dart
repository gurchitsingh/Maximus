// The session (CONTRACTS 14.5): loading while secure storage is read, then
// signed in (a stored refresh token, even offline) or signed out. Every
// sign-in path ends in AuthTokens.save; every sign-out path clears it.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_controller.dart';
import '../../data/api/api_error.dart';
import '../../data/api/auth_tokens.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';
import '../reader/read_aloud.dart';
import 'auth_api.dart';
import 'auth_models.dart';
import 'google_auth.dart';

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The signed-in user, or null.
final currentUserProvider = Provider<AuthUser?>(
  (ref) => switch (ref.watch(authControllerProvider)) {
    SignedIn(:final user) => user,
    _ => null,
  },
);

class AuthController extends Notifier<AuthState> {
  AuthTokens get _tokens => ref.read(authTokensProvider);
  AuthApi get _api => ref.read(authApiProvider);

  @override
  AuthState build() {
    final tokens = ref.watch(authTokensProvider);
    // Refresh rejected by the server: clear the session, keep the drift
    // data (14.5), and the router sends the user to Welcome.
    final sub = tokens.sessionEnded.listen((_) {
      if (ref.mounted) state = const SignedOut();
    });
    ref.onDispose(sub.cancel);
    unawaited(_restore(tokens));
    return const AuthLoading();
  }

  Future<void> _restore(AuthTokens tokens) async {
    AuthState next;
    try {
      final store = tokens.store;
      final id = await store.read(TokenKeys.userId);
      next = id != null && await tokens.hasSession
          ? SignedIn(
              AuthUser(
                id: id,
                email: await store.read(TokenKeys.userEmail),
                displayName: await store.read(TokenKeys.userName),
              ),
            )
          : const SignedOut();
    } catch (_) {
      // Unreadable secure storage (restored backup on a new phone): start
      // signed out rather than crash.
      next = const SignedOut();
    }
    if (ref.mounted && state is AuthLoading) state = next;
  }

  Future<void> _start(TokenGrant grant) async {
    await _tokens.save(grant);
    state = SignedIn(AuthUser.fromJson(grant.user));
  }

  Future<void> signInWithEmail(String email, String password) async =>
      _start(await _api.signIn(email.trim(), password));

  Future<void> signUp(String email, String password, {String? name}) async {
    final trimmed = name?.trim();
    await _start(
      await _api.signUp(
        email.trim(),
        password,
        displayName: trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  /// False when the user closed Google's picker.
  Future<bool> signInWithGoogle() async {
    final idToken = await ref.read(googleAuthProvider).idToken();
    if (idToken == null) return false;
    await _start(await _api.google(idToken));
    return true;
  }

  Future<void> forgotPassword(String email) =>
      _api.forgotPassword(email.trim());

  /// GET /v1/me: fills in the sign-in methods. Offline
  /// keeps what is stored.
  Future<AuthUser?> refreshUser() async {
    if (state is! SignedIn) return null;
    final user = await _api.me();
    await _tokens.saveUser({
      'id': user.id,
      'email': user.email,
      'display_name': user.displayName,
    });
    final s = state;
    if (s is SignedIn) state = SignedIn(user);
    return user;
  }

  /// Sign out (14.5): revoke the refresh token (best effort, offline is
  /// fine), forget Google's account, wipe the personal tables (the content
  /// cache stays), clear secure storage.
  Future<void> signOut() async {
    final refresh = await _tokens.store.read(TokenKeys.refreshToken);
    if (refresh != null) {
      try {
        await _api.signOut(refresh);
      } on ApiException {
        // Offline or server down: clear locally anyway.
      }
    }
    await _endSession();
  }

  /// DELETE /v1/me (17). Email accounts pass [password]. Google-only
  /// accounts need an access token under 5 minutes old, so one is fetched
  /// first. Throws [ApiException] and keeps the session on failure.
  Future<void> deleteAccount({String? password}) async {
    if (password == null) {
      final fresh = await _tokens.refresh(ref.read(apiClientProvider));
      if (fresh == null) {
        // The refresh token was rejected: the session has already ended.
        throw const ApiException(code: 'unauthorized', status: 401);
      }
    }
    await _api.deleteMe(password: password);
    await _endSession();
  }

  Future<void> _endSession() async {
    // No sync may write or push while (or after) the data is wiped.
    await ref.read(syncServiceProvider).stop();
    await ref.read(googleAuthProvider).signOut();
    await ref.read(readAloudProvider.notifier).stop();
    await ref.read(databaseProvider).wipeUserData();
    ref.read(themeSettingsProvider.notifier).reset();
    await _tokens.clear();
    state = const SignedOut();
  }
}
