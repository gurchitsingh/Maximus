import 'package:material_ui/material_ui.dart';

import '../placeholder_body.dart';

/// Feed has no top bar (DESIGN_SPEC 7.9).
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: PlaceholderBody(title: 'Feed', session: 'S8'),
    );
  }
}
