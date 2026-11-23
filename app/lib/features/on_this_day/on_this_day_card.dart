// On This Day card (DESIGN_SPEC 7.16, 11.19; CONTRACTS 2.7). It lives on
// Home, which adds `const OnThisDayCard()` once S12 brings live data.
// No data = nothing rendered.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/dev/dev_feed_source.dart';
import '../../data/models/on_this_day.dart';
import '../../data/providers.dart';
import '../../data/repositories/on_this_day_repository.dart';
import '../shared/title_visuals.dart';

/// Bundled sample until S12 wires GET /v1/on-this-day.
final onThisDaySourceProvider = Provider<OnThisDaySource>(
  (_) => DevFeedSource(rootBundle),
);

/// Keyed by the local day, so a new day loads a new card.
final onThisDayProvider = FutureProvider.family<OnThisDay?, DateTime>(
  (ref, day) => OnThisDayRepository(
    ref.watch(databaseProvider),
    ref.watch(onThisDaySourceProvider),
  ).today(day),
);

const _months = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

/// "ON THIS DAY · 21 NOVEMBER" (local date).
String onThisDayKicker(DateTime d) =>
    'ON THIS DAY · ${d.day} ${_months[d.month - 1]}';

class OnThisDayCard extends ConsumerWidget {
  const OnThisDayCard({super.key, this.now});

  /// Injected in tests; defaults to the device's local time.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = now ?? DateTime.now();
    final day = DateTime(t.year, t.month, t.day);
    final otd = ref.watch(onThisDayProvider(day)).value;
    if (otd == null) return const SizedBox.shrink();

    final c = context.mx;
    final item = otd.featured;
    final linked = item.linkedTitleId;
    final radius = BorderRadius.circular(MxRadius.resume);
    final body = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(onThisDayKicker(day)),
          const SizedBox(height: 10),
          Text(item.titleLine, style: MxText.otdTitle.copyWith(color: c.text)),
          const SizedBox(height: 6),
          Text(item.text, style: MxText.body.copyWith(color: c.textMuted)),
          const SizedBox(height: 10),
          Text(otd.caption, style: MxText.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: linked != null,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          // Unlinked items are not tappable (2.7).
          child: linked == null
              ? body
              : InkWell(
                  onTap: () => openTitleSheet(context, linked),
                  overlayColor: WidgetStatePropertyAll(
                    c.text.withValues(alpha: 0.08),
                  ),
                  child: body,
                ),
        ),
      ),
    );
  }
}
