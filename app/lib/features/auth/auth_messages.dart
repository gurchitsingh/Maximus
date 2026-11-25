// Friendly copy for the server's error codes (CONTRACTS 3.5, 14.4). The
// server's own `message` is never shown: the app owns its wording.
import '../../data/api/api_error.dart';
import 'google_auth.dart';

String authErrorMessage(Object error) {
  if (error is GoogleAuthUnavailable) {
    return 'Google sign-in is not available on this phone right now. '
        'Try again, or use email.';
  }
  if (error is! ApiException) {
    return 'Something went wrong. Try again.';
  }
  return switch (error.code) {
    'invalid_credentials' => 'Wrong email or password',
    'email_taken' when error.details?['method'] == 'google' =>
      'This email signs in with Google. Use Continue with Google.',
    'email_taken' => 'There is already an account with this email. Sign in.',
    'weak_password' => 'Use a password of 10 to 128 characters.',
    'validation_error' ||
    'bad_request' => 'Check the email address and try again.',
    'google_token_invalid' => 'Google sign-in did not work. Try again.',
    'rate_limited' => _tooMany(error.retryAfterS),
    'unauthorized' ||
    'token_expired' ||
    'token_invalid' ||
    'token_reused' => 'Your session has ended. Sign in again.',
    'reauth_required' =>
      'For your safety, sign out and sign in again, then delete the account.',
    ApiException.offline =>
      'You are offline. Connect to the internet and try again.',
    _ => 'Something went wrong on our side. Try again in a moment.',
  };
}

String _tooMany(int? seconds) {
  if (seconds == null || seconds <= 60) {
    return 'Too many tries. Wait a minute and try again.';
  }
  final minutes = (seconds / 60).ceil();
  return 'Too many tries. Try again in $minutes minutes.';
}

/// Email sign-in (D48): every rejected attempt reads the same, so the
/// screen never reveals whether the email has an account. Offline, rate
/// limits and server faults keep their own honest copy.
String signInErrorMessage(Object error) {
  if (error is ApiException &&
      error.code != ApiException.offline &&
      error.code != 'rate_limited' &&
      error.status != null &&
      error.status! < 500) {
    return 'Wrong email or password';
  }
  return authErrorMessage(error);
}
