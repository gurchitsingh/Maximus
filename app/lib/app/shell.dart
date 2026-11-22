// Main tab shell: Home, Library, Feed, Study (DESIGN_SPEC 7.8, 9).
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/tokens.dart';
import '../core/widgets/mx_nav_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mx.bg,
      body: shell,
      bottomNavigationBar: MxNavBar(
        items: MxNavItem.mainTabs,
        currentIndex: shell.currentIndex,
        // Tapping the active tab returns that tab to its first page.
        onSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
