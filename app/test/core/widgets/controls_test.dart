import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:maximus/core/theme/tokens.dart';
import 'package:maximus/core/widgets/widgets.dart';

import '../../helpers.dart';

void main() {
  group('RatingButtons', () {
    testWidgets('tap selects, note follows, tap again clears', (tester) async {
      Rating? value;
      await tester.pumpWidget(
        themed(
          StatefulBuilder(
            builder: (context, setState) => RatingButtons(
              value: value,
              onChanged: (r) => setState(() => value = r),
            ),
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text(Rating.unratedNote), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Like'));
      await tester.pumpAndSettle();
      expect(value, Rating.up);
      expect(find.text('Noted. Similar topics move up.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Not for me'));
      await tester.pumpAndSettle();
      expect(value, Rating.down);
      expect(find.text('Noted. You will see less like this.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Not for me'));
      await tester.pumpAndSettle();
      expect(value, isNull);
    });

    testWidgets('selected button fills with accent and scales up', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(RatingButtons(value: Rating.okay, onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      final scales = tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .map((s) => s.scale)
          .toList();
      expect(scales, [1.0, MxMotion.ratingScale, 1.0]);
      final fills = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(RatingButtons),
              matching: find.byType(Material),
            ),
          )
          .map((m) => m.color)
          .toList();
      expect(fills[1], MxColors.dark.accent);
    });
  });

  group('Buttons', () {
    testWidgets('disabled primary is 0.4 opacity and ignores taps', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(const PrimaryButton(label: 'Pick 2 more', onPressed: null)),
      );
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Pick 2 more'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
      await tester.tap(find.text('Pick 2 more'), warnIfMissed: false);
      expect(tester.getSize(find.byType(PrimaryButton)).height, 56);
    });

    testWidgets('Add toggles to Added', (tester) async {
      var added = false;
      await tester.pumpWidget(
        themed(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 170,
              child: AddButton(
                added: added,
                onPressed: () => setState(() => added = !added),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Add'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Added'), findsOneWidget);
    });
  });

  testWidgets('AnswerOption shows icon and word, not colour alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Column(
          children: [
            AnswerOption(label: 'Carthage', state: AnswerState.right),
            AnswerOption(label: 'Athens', state: AnswerState.wrong),
          ],
        ),
      ),
    );
    expect(find.text('Right'), findsOneWidget);
    expect(find.text('Not quite'), findsOneWidget);
  });

  testWidgets('nav bar marks the active tab and reports taps', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      themed(
        StatefulBuilder(
          builder: (context, setState) => MxNavBar(
            items: MxNavItem.mainTabs,
            currentIndex: index,
            onSelected: (i) => setState(() => index = i),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Feed'));
    await tester.pump();
    expect(index, 2);
    final label = tester.widget<Text>(find.text('Feed'));
    expect(label.style!.fontWeight, FontWeight.w800);
    expect(label.style!.color, MxColors.dark.accentText);
  });
}
