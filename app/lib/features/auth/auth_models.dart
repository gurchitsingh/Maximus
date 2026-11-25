// Session state and the `User` shape of CONTRACTS 14.1.
import 'package:meta/meta.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.emailVerified,
    this.hasPassword,
    this.hasGoogle,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String,
    email: j['email'] as String?,
    displayName: j['display_name'] as String?,
    emailVerified: j['email_verified'] as bool?,
    hasPassword: j['has_password'] as bool?,
    hasGoogle: j['has_google'] as bool?,
  );

  final String id;
  final String? email;
  final String? displayName;

  /// Null when only the stored id, email and name are known (offline cold
  /// start); GET /v1/me fills them in.
  final bool? emailVerified;
  final bool? hasPassword;
  final bool? hasGoogle;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified &&
      other.hasPassword == hasPassword &&
      other.hasGoogle == hasGoogle;

  @override
  int get hashCode => Object.hash(
    id,
    email,
    displayName,
    emailVerified,
    hasPassword,
    hasGoogle,
  );
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
  const SignedIn(this.user, {this.showVerify = false});

  final AuthUser user;

  /// True right after an email sign-up: the router shows Verify email once.
  final bool showVerify;

  @override
  bool operator ==(Object other) =>
      other is SignedIn && other.user == user && other.showVerify == showVerify;

  @override
  int get hashCode => Object.hash(user, showVerify);
}
