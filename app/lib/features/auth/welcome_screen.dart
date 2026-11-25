// Welcome (All Pages 1.1, prototype `splash`): the disc on the splash
// colour, the same in both themes. It is also the loading screen while
// secure storage is read. Signed out, it moves on to Sign in after 1.5 s
// or on a tap; signed in, the router has already sent the user on.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'auth_controller.dart';
import 'auth_models.dart';
import 'auth_redirect.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(MxMotion.splash, () {
      _shown = true;
      _next();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (!mounted) return;
    if (ref.read(authControllerProvider) is SignedOut) {
      context.go(AuthPaths.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Storage read finished after the 1.5 s: move on now.
    ref.listen(authControllerProvider, (_, next) {
      if (_shown && next is SignedOut) _next();
    });
    return Scaffold(
      backgroundColor: MxFixed.splashBg,
      body: Semantics(
        button: true,
        label: 'Continue',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _next,
          child: const Center(child: MxLogo(size: 168, color: MxFixed.ring)),
        ),
      ),
    );
  }
}
