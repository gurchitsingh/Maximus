import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/mx_logo.dart';
import 'router.dart';

class MaximusApp extends ConsumerWidget {
  const MaximusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final theme = MxTheme.build(settings.variant, textSize: settings.textSize);
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: MxTheme.systemOverlay(settings.variant),
        // Respect the OS font scale, but cap it so fixed-height controls
        // (48 to 56 dp) keep their text inside.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child!,
        ),
      ),
    );
  }
}
