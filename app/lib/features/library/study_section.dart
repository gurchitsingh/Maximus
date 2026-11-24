// "Your study list": the first Library section, under the hero (DESIGN_SPEC
// 15.3, CONTRACTS 19). Row tap opens the reader at the next unfinished lesson
// and swipe removes (FLOW 5, DESIGN_SPEC 11.12). Empty: picture, text, link.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/app_database.dart';
import '../../data/models/catalogue.dart';
import '../../data/providers.dart';
import '../../data/repositories/user_state_repository.dart';
import '../shared/title_visuals.dart';

class StudySection extends ConsumerWidget {
  const StudySection({super.key, required this.catalogue, this.onBrowse});

  final Catalogue catalogue;

  /// Empty-state link: scrolls the Library to the poster rows.
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = catalogue;
    final items = ref.watch(studyListProvider).value ?? const <StudyItemRow>[];
    final count = items.length;
    final repo = ref.read(userStateRepositoryProvider);
    return Column(
      children: [
        const SizedBox(height: MxSpace.sectionGap),
        SectionHeader(
          title: 'Your study list',
          trailing: count == 0
              ? null
              : Text(
                  count == 1 ? '1 topic' : '$count topics',
                  style: MxText.body.copyWith(color: context.mx.textMuted),
                ),
        ),
        const SizedBox(height: MxSpace.headingToContent),
        if (items.isEmpty)
          _empty(context, c)
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: _row(context, ref, repo, c, item.titleId),
            ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _empty(BuildContext context, Catalogue c) {
    final m = context.mx;
    final greece = c.title('ancient-greece') ?? c.titles.firstOrNull;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: m.divider, width: 2),
      ),
      child: Row(
        children: [
          if (greece != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(MxRadius.thumb),
              child: SizedBox.square(
                dimension: 64,
                child: TitleArt(data: titleArt(greece, c.image)),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing here yet',
                  style: MxText.rowTitle.copyWith(color: m.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a topic from any poster below and it waits here.',
                  style: MxText.body.copyWith(color: m.textMuted),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MxTextButton(
                    label: 'Browse the library',
                    onPressed: onBrowse,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    UserStateRepository repo,
    Catalogue c,
    String id,
  ) {
    final t = c.title(id);
    final progress = ref.watch(titleProgressProvider(id));
    final name = t?.name ?? id;
    void remove() {
      repo.setOnStudyList(id, false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Removed $name'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => repo.setOnStudyList(id, true),
            ),
          ),
        );
    }

    return Dismissible(
      key: ValueKey('study-$id'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => remove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: context.mx.errorContainer,
          borderRadius: BorderRadius.circular(MxRadius.card),
        ),
        child: MxIcon(MxIcons.x, size: 24, color: context.mx.error),
      ),
      child: StudyRow(
        card: true,
        art: t == null
            ? ArtData(bg: context.mx.surfaceRaised, tint: context.mx.textMuted)
            : titleArt(t, c.image),
        name: name,
        // Gone from the catalogue (CONTRACTS 3.6): keep it removable.
        subtitle: t == null ? 'No longer available' : progress.label,
        progress: progress.fraction,
        onTap: t == null || t.lessonCount == 0
            ? null
            : () => openReader(context, ref, id),
        onRemove: remove,
      ),
    );
  }
}
