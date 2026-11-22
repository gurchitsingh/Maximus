// Study list (DESIGN_SPEC 9.2.6, 9.2.7, 7.6). Row tap opens the reader at
// the next unfinished lesson and swipe removes (FLOW 5, DESIGN_SPEC 11.12).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../shared/title_visuals.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const MxTabTopBar(title: 'Study list'),
          Expanded(child: _StudyList()),
        ],
      ),
    );
  }
}

class _StudyList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final list = ref.watch(studyListProvider);
    if (catalogue.isLoading || list.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: TextSkeleton(lines: 6),
      );
    }
    final c = catalogue.value;
    final items = list.value ?? const <StudyItemRow>[];
    if (c == null) {
      return ErrorState(
        title: 'Could not load the library',
        body: 'Connect to the internet to set up Maximus.',
        offline: true,
        onRetry: () => ref.invalidate(catalogueProvider),
      );
    }
    if (items.isEmpty) {
      final greece = c.title('ancient-greece') ?? c.titles.firstOrNull;
      return EmptyState(
        art: greece == null
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(MxRadius.emptyArt),
                child: SizedBox.square(
                  dimension: 150,
                  child: TitleArt(data: titleArt(greece, c.image)),
                ),
              ),
        title: 'Nothing here yet',
        body: 'Add a topic from the library and it will wait for you here.',
        actionLabel: 'Browse the library',
        onAction: () => context.go(AppRoute.library.path),
      );
    }
    final repo = ref.read(userStateRepositoryProvider);
    return ListView.separated(
      primary: false,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final id = items[i].titleId;
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
                ? ArtData(
                    bg: context.mx.surfaceRaised,
                    tint: context.mx.textMuted,
                  )
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
      },
    );
  }
}
