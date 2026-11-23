// About: version and what the app is. Version matches pubspec.yaml
// (a test keeps them in step).
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../reader/lesson_body.dart' show openExternal;

const appVersion = '1.0.0';
const appBuild = '1';

Future<void> showAboutSheet(BuildContext context) => showMxBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (ctx) {
    final c = ctx.mx;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 4),
          Text(value, style: MxText.body.copyWith(color: c.text)),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('About Maximus', style: MxText.emptyTitle.copyWith(color: c.text)),
        const SizedBox(height: 16),
        row('Version', '$appVersion (build $appBuild)'),
        row(
          'What it is',
          'Short history lessons, quizzes and a fact feed. Everything you do '
              'stays on this phone.',
        ),
        row(
          'Where lessons come from',
          'Lesson text is adapted from Wikipedia, shortened, and shared under '
              'CC BY-SA 4.0. Images come from Wikimedia Commons. See Credits '
              'for every source.',
        ),
        const SizedBox(height: 4),
        SecondaryButton(
          label: 'Read the CC BY-SA 4.0 licence',
          icon: MxIcons.arrowRight,
          onPressed: () =>
              openExternal('https://creativecommons.org/licenses/by-sa/4.0/'),
        ),
      ],
    );
  },
);
