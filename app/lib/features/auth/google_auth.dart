// Google sign-in (CONTRACTS 14.3): google_sign_in with serverClientId = the
// web OAuth client id, which is not a secret and comes from the build:
// `--dart-define=GOOGLE_CLIENT_ID=<id>.apps.googleusercontent.com`.
// Without it the Google button shows disabled with a note.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

/// Thrown when Google could not give an ID token (misconfigured, no Play
/// services, no account picker).
class GoogleAuthUnavailable implements Exception {
  const GoogleAuthUnavailable(this.reason);
  final String reason;

  @override
  String toString() => 'GoogleAuthUnavailable($reason)';
}

abstract class GoogleAuth {
  /// False when this build has no GOOGLE_CLIENT_ID.
  bool get available;

  /// Opens Google's account picker. Returns the ID token, or null when the
  /// user closed the picker.
  Future<String?> idToken();

  /// Forgets the picked account on this device. Never throws.
  Future<void> signOut();
}

class PluginGoogleAuth implements GoogleAuth {
  PluginGoogleAuth({this.clientId = googleClientId});

  final String clientId;
  Future<void>? _init;

  @override
  bool get available => clientId.isNotEmpty;

  Future<void> _ready() =>
      _init ??= GoogleSignIn.instance.initialize(serverClientId: clientId);

  @override
  Future<String?> idToken() async {
    if (!available) throw const GoogleAuthUnavailable('no client id');
    try {
      await _ready();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const GoogleAuthUnavailable('authenticate not supported');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const GoogleAuthUnavailable('no id token');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      _init = null;
      throw GoogleAuthUnavailable(e.code.name);
    }
  }

  @override
  Future<void> signOut() async {
    if (!available) return;
    try {
      await _ready();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Best effort: the app session is already gone.
    }
  }
}

final googleAuthProvider = Provider<GoogleAuth>((_) => PluginGoogleAuth());
