import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/widgets/widgets.dart';
import '../placeholder_body.dart';

/// Greeting by local time of day (DESIGN_SPEC 11.19).
String greetingFor(DateTime now) => switch (now.hour) {
  >= 5 && < 12 => 'Good morning',
  >= 12 && < 18 => 'Good afternoon',
  _ => 'Good evening',
};

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          MxTabTopBar(
            title: greetingFor(DateTime.now()),
            // Hidden gallery: long-press the logo (debug builds only).
            leading: GestureDetector(
              onLongPress: kDebugMode
                  ? () => context.push(AppRoute.gallery.path)
                  : null,
              child: const MxLogo(size: 30),
            ),
            trailing: MxIconButton(
              icon: MxIcons.settings,
              label: 'Settings',
              onPressed: () => context.push(AppRoute.settings.path),
            ),
          ),
          const Expanded(
            child: PlaceholderBody(title: 'Home', session: 'S5'),
          ),
        ],
      ),
    );
  }
}
