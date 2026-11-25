// Where the router sends a location for a given session (CONTRACTS 19,
// All Pages order: Welcome, Sign in or Create account, onboarding, Home).
// Pure, so every rule is unit tested.
import 'auth_models.dart';

abstract final class AuthPaths {
  static const welcome = '/';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const home = '/home';

  /// Screens a signed-out user may see.
  static const signedOut = {welcome, signIn, signUp, forgotPassword};
}

/// Returns the path to go to instead of [path], or null to stay.
///
/// [onboardingPath] is the first onboarding step; null while onboarding is
/// not built (S5), so signed-in users go straight to Home.
String? authRedirect(
  String path,
  AuthState auth, {
  String? onboardingPath,
  bool onboardingDone = false,
}) {
  switch (auth) {
    case AuthLoading():
      // Welcome doubles as the loading screen while secure storage is read.
      return path == AuthPaths.welcome ? null : AuthPaths.welcome;
    case SignedOut():
      return AuthPaths.signedOut.contains(path) ? null : AuthPaths.welcome;
    case SignedIn(:final showVerify):
      final onAuthScreen =
          AuthPaths.signedOut.contains(path) || path == AuthPaths.verifyEmail;
      if (showVerify) {
        return path == AuthPaths.verifyEmail
            ? null
            : onAuthScreen
            ? AuthPaths.verifyEmail
            : null;
      }
      final needsOnboarding = onboardingPath != null && !onboardingDone;
      if (onAuthScreen) {
        return needsOnboarding ? onboardingPath : AuthPaths.home;
      }
      if (needsOnboarding && !path.startsWith('/onboarding')) {
        return onboardingPath;
      }
      return null;
  }
}
