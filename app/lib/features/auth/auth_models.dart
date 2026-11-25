// Session state and the `User` shape of CONTRACTS 14.1.
import 'package:meta/meta.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.hasPassword,
    this.hasGoogle,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String,
    email: j['email'] as String?,
    displayName: j['display_name'] as String?,
    hasPassword: j['has_password'] as bool?,
    hasGoogle: j['has_google'] as bool?,
  );

  final String id;
  final String? email;
  final String? displayName;

  /// Null when only the stored id, email and name are known (offline cold
  /// start); GET /v1/me fills them in.
  final bool? hasPassword;
  final bool? hasGoogle;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.hasPassword == hasPassword &&
      other.hasGoogle == hasGoogle;

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, hasPassword, hasGoogle);
}

/// Signed out, signed in, or still reading secure storage.
sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);

  final AuthUser user;

  @override
  bool operator ==(Object other) => other is SignedIn && other.user == user;

  @override
  int get hashCode => user.hashCode;
}
