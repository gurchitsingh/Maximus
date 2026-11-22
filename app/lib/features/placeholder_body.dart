// Stand-in body for screens built in later sessions (S5 to S9).
import 'package:material_ui/material_ui.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({
    super.key,
    required this.title,
    required this.session,
  });

  final String title;

  /// Plan session that builds the real screen, e.g. "S5".
  final String session;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: MxText.emptyTitle.copyWith(color: c.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Placeholder. The real screen is built in $session.',
              textAlign: TextAlign.center,
              style: MxText.body.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
