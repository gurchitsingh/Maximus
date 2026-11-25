// S18: the router's auth rules (CONTRACTS 19, All Pages order).
import 'package:flutter_test/flutter_test.dart';
import 'package:maximus/features/auth/auth_models.dart';
import 'package:maximus/features/auth/auth_redirect.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'ada@example.com');
  const signedIn = SignedIn(user);

  test('loading holds everything on Welcome', () {
    expect(authRedirect('/', const AuthLoading()), isNull);
    expect(authRedirect('/library', const AuthLoading()), '/');
    expect(authRedirect('/sign-in', const AuthLoading()), '/');
  });

  test('signed out: only Welcome and the sign-in screens', () {
    for (final p in ['/', '/sign-in', '/sign-up', '/forgot-password']) {
      expect(authRedirect(p, const SignedOut()), isNull, reason: p);
    }
    for (final p in [
      '/home',
      '/library',
      '/settings',
      '/sheet/roman-history',
      '/title/roman-history/lesson/l1',
    ]) {
      expect(authRedirect(p, const SignedOut()), '/', reason: p);
    }
  });

  test('signed in: auth screens go to Home, the app stays put', () {
    for (final p in ['/', '/sign-in', '/sign-up']) {
      expect(authRedirect(p, signedIn), '/home', reason: p);
    }
    for (final p in ['/home', '/library', '/settings', '/sheet/x']) {
      expect(authRedirect(p, signedIn), isNull, reason: p);
    }
  });

  test('onboarding (once S5 builds it) comes before Home', () {
    const ob = '/onboarding/theme';
    expect(authRedirect('/sign-in', signedIn, onboardingPath: ob), ob);
    expect(authRedirect('/home', signedIn, onboardingPath: ob), ob);
    expect(
      authRedirect('/onboarding/topics', signedIn, onboardingPath: ob),
      isNull,
    );
    expect(
      authRedirect(
        '/sign-in',
        signedIn,
        onboardingPath: ob,
        onboardingDone: true,
      ),
      '/home',
    );
    expect(
      authRedirect('/home', signedIn, onboardingPath: ob, onboardingDone: true),
      isNull,
    );
  });
}
