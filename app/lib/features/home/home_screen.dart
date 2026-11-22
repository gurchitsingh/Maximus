// Home (DESIGN_SPEC 9.2.1, 9.2.2; FLOW 3): resume card, study rows, For you,
// quiz scores. On this day stays hidden until S12 brings live data (11.19);
// quiz score tiles fill in S7. S9 finishes the dashboard.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/match/rows.dart';
import '../shared/title_visuals.dart';

/// Greeting by local time of day (DESIGN_SPEC 11.19).
String greetingFor(DateTime now) => switch (now.hour) {
  >= 5 && < 12 => 'Good morning',
  >= 12 && < 18 => 'Good afternoon',
  _ => 'Good evening',
};

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          MxTabTopBar(
            title: greetingFor(DateTime.now()),
            // Hidden gallery: long-press the logo (debug builds only).
            leading: GestureDetector(
              onLongPress: kDebugMode
                  ? () => context.push(AppRoute.gallery.path)
                  : null,
              child: const MxLogo(size: 30),
            ),
            trailing: MxIconButton(
              icon: MxIcons.settings,
              label: 'Settings',
              onPressed: () => context.push(AppRoute.settings.path),
            ),
          ),
          const Expanded(child: _HomeBody()),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider);
    final c = catalogue.value;
    if (c == null) {
      return catalogue.hasError
          ? ErrorState(
              title: 'Could not load the library',
              body: 'Connect to the internet to set up Maximus.',
              offline: true,
              onRetry: () => ref.invalidate(catalogueProvider),
            )
          : const PosterRowSkeleton();
    }
    final match = ref.watch(matchProvider);
    final studyIds = ref.watch(studyIdsProvider);
    final study = [
      for (final r
          in ref.watch(studyListProvider).value ?? const <StudyItemRow>[])
        if (c.title(r.titleId) != null) c.title(r.titleId)!,
    ];
    final forYou = [for (final id in forYouIds(match, studyIds)) c.title(id)!];

    return ListView(
      // Tabs stay alive in an IndexedStack: never share the primary controller.
      primary: false,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        const _ResumeSlot(),
        if (study.isNotEmpty) ...[
          const SizedBox(height: MxSpace.sectionGap),
          const SectionHeader(title: 'Your study list'),
          const SizedBox(height: MxSpace.headingToContent),
          for (final t in study.take(2))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Consumer(
                builder: (context, ref, _) {
                  final p = ref.watch(titleProgressProvider(t.id));
                  return StudyRow(
                    art: titleArt(t, c.image),
                    name: t.name,
                    subtitle: p.label,
                    progress: p.fraction,
                    onTap: t.lessonCount == 0
                        ? null
                        : () => openReader(context, ref, t.id),
                  );
                },
              ),
            ),
        ],
        PosterRow(
          title: 'For you',
          posterWidth: 128,
          items: [
            for (final t in forYou)
              PosterItem(
                id: t.id,
                data: posterData(t, c),
                matchPercent: match.pctOf(t.id),
              ),
          ],
          onTap: (id) => openTitleSheet(context, id),
        ),
        const SizedBox(height: MxSpace.sectionGap),
        const SectionHeader(title: 'Your quiz scores'),
        const SizedBox(height: MxSpace.headingToContent),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: EmptyScores(),
        ),
      ],
    );
  }
}

/// Resume card: the newest opened lesson of a title still in the catalogue.
class _ResumeSlot extends ConsumerWidget {
  const _ResumeSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(catalogueProvider).value;
    final rows =
        ref.watch(progressProvider).value ?? const <LessonProgressRow>[];
    if (c == null) return const SizedBox.shrink();
    final last = rows.where((r) => c.title(r.titleId) != null).firstOrNull;
    if (last == null) return const SizedBox.shrink();
    final t = c.title(last.titleId)!;
    final detail = ref.watch(titleDetailProvider(t.id)).value;
    final p = ref.watch(titleProgressProvider(t.id));
    if (detail == null || detail.lessons.isEmpty) {
      return const SizedBox.shrink();
    }
    final lesson = p.resumeLesson(detail.lessons);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: ResumeCard(
        art: titleArt(t, c.image),
        titleName: t.name,
        lessonLine: 'Lesson ${lesson.index}: ${lesson.heading}',
        progress: p.fraction,
        onTap: () => openReader(context, ref, t.id),
      ),
    );
  }
}
