import 'package:material_ui/material_ui.dart';

import '../placeholder_body.dart';

/// Library has no top bar: the hero banner starts at the top (DESIGN_SPEC 2.3).
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: PlaceholderBody(title: 'Library', session: 'S5'),
    );
  }
}
