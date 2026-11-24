// Compact Fact of the day card (DESIGN_SPEC 15.2): 56 dp thumbnail, date
// line, one fact. Hidden when there is no fact.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../shared/title_visuals.dart';
import 'fact_of_the_day.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Fact of the day · 24 November".
String factDateLine(DateTime d) =>
    'Fact of the day · ${d.day} ${_monthNames[d.month - 1]}';

class FactOfTheDayCard extends ConsumerWidget {
  const FactOfTheDayCard({super.key, this.now});

  /// Injected in tests; defaults to the device's local time.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = now ?? DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final fact = ref.watch(todayFactProvider(day));
    if (fact == null) return const SizedBox.shrink();

    final c = context.mx;
    final catalogue = ref.watch(catalogueProvider).value;
    final title = catalogue?.title(fact.titleId);
    final thumb = SizedBox.square(
      dimension: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: title == null
            ? ExcludeSemantics(
                child: TintedGradient(bg: c.accentContainer, tint: c.accent),
              )
            : TitleArt(data: titleArt(title, catalogue!.image)),
      ),
    );
    final body = Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factDateLine(day).toUpperCase(),
                  style: MxText.kicker.copyWith(
                    fontSize: 11,
                    color: c.accentText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fact.text,
                  style: MxText.sub.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, MxSpace.sectionGap, 20, 0),
      child: Semantics(
        container: true,
        button: title != null,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: c.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: double.infinity,
            // Not in the catalogue: nothing happens, no error (CONTRACTS 20).
            child: title == null
                ? body
                : InkWell(
                    onTap: () => openTitleSheet(context, title.id),
                    overlayColor: WidgetStatePropertyAll(
                      c.text.withValues(alpha: 0.08),
                    ),
                    child: body,
                  ),
          ),
        ),
      ),
    );
  }
}
