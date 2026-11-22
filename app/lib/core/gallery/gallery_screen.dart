// Hidden widget gallery (CONTRACTS 8.3 /dev/gallery, debug builds only).
// Shows every shared widget in dark, light or sepia, picked at the top,
// independent of the app theme.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';
import 'gallery_samples.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late MxThemeVariant _variant = ref.read(themeSettingsProvider).variant;

  @override
  Widget build(BuildContext context) {
    final textSize = ref.watch(themeSettingsProvider).textSize;
    final theme = MxTheme.build(_variant, textSize: textSize);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final c = context.mx;
          return Scaffold(
            backgroundColor: c.bg,
            body: AnnotatedRegion<SystemUiOverlayStyle>(
              value: MxTheme.systemOverlay(_variant),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const MxPushedTopBar(title: 'Widget gallery'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: SegmentedChoice<MxThemeVariant>(
                        options: MxThemeVariant.values,
                        value: _variant,
                        labelOf: (v) => v.label,
                        onChanged: (v) => setState(() => _variant = v),
                      ),
                    ),
                    Divider(color: c.divider),
                    Expanded(child: _GalleryBody(theme: theme)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GalleryBody extends StatefulWidget {
  const _GalleryBody({required this.theme});
  final ThemeData theme;

  @override
  State<_GalleryBody> createState() => _GalleryBodyState();
}

class _GalleryBodyState extends State<_GalleryBody> {
  bool _added = false;
  bool _feedSaved = true;
  Rating? _rating = Rating.up;
  String _segment = 'Medium';
  String _group = 'By era';
  int _mainTab = 0;
  int _topicTab = 0;
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    const roman = GallerySamples.roman;
    return ListView(
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        _Section('Colour roles', child: _Swatches(colors: c)),
        const _Section('Type scale', child: _TypeScale()),
        _Section(
          'Poster lettering (2.4) and sheet lettering',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in GallerySamples.all.take(4)) ...[
                SheetLettering(lines: p.lines, kind: p.lettering),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        _Section(
          'Poster card: gradient fallback, badge, sizes',
          padded: false,
          child: SizedBox(
            height: 128 * 1.5,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: GallerySamples.all.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => PosterCard(
                data: GallerySamples.all[i],
                width: 128,
                matchPercent: i == 4 ? null : 94 - i * 3,
                onTap: () {},
              ),
            ),
          ),
        ),
        _Section(
          'Poster 170 + compact badge, 112 alt, match badge alone',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterCard(
                data: GallerySamples.egypt,
                width: 170,
                matchPercent: 96,
                compactBadge: true,
                onTap: () {},
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PosterCard(data: GallerySamples.napoleon, width: 112),
                    const SizedBox(height: 12),
                    const MatchBadge(percent: 87),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Section(
          'Buttons',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrimaryButton(label: 'Next', onPressed: () {}),
              const SizedBox(height: 10),
              const PrimaryButton(label: 'Pick 2 more', onPressed: null),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Review lessons you missed',
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              AccentOutlineButton.studyList(
                added: _added,
                onPressed: () => setState(() => _added = !_added),
              ),
              const SizedBox(height: 10),
              TintButton(label: 'Start', tint: roman.tint, onPressed: () {}),
              const SizedBox(height: 10),
              TintButton(
                label: 'Take the quiz',
                tint: GallerySamples.french.tint,
                icon: null,
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 170,
                child: AddButton(
                  added: _added,
                  onPressed: () => setState(() => _added = !_added),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MxTextButton(
                    label: 'Skip',
                    style: MxTextButtonStyle.skip,
                    onPressed: () {},
                  ),
                  MxTextButton(label: 'Forgot password?', onPressed: () {}),
                  MxTextButton(
                    label: 'Sign in',
                    style: MxTextButtonStyle.toggleLink,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  MxIconButton(
                    icon: MxIcons.chevronLeft,
                    label: 'Back',
                    onPressed: () {},
                  ),
                  MxIconButton(
                    icon: MxIcons.settings,
                    label: 'Settings',
                    onPressed: () {},
                  ),
                  MxIconButton(
                    icon: MxIcons.x,
                    label: 'Remove',
                    size: 20,
                    color: c.textMuted,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: MxIcons.play,
                    label: 'Listen',
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: MxIcons.send,
                    label: 'Send',
                    diameter: 52,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        _Section(
          'On artwork: pills and feed actions',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MxRadius.resume),
            child: SizedBox(
              height: 270,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TintedGradient(bg: roman.bg, tint: roman.tint),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: TopicTag(label: 'Roman history', tint: roman.tint),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PillCta(
                          label: 'Resume',
                          size: PillSize.resume,
                          tint: roman.tint,
                          onPressed: () {},
                        ),
                        const SizedBox(height: 8),
                        PillCta(
                          label: 'Start',
                          tint: roman.tint,
                          onPressed: () {},
                        ),
                        const SizedBox(height: 8),
                        PillCta(
                          label: 'Go deeper',
                          size: PillSize.goDeeper,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 16,
                    child: Column(
                      children: [
                        FeedActionButton(
                          icon: MxIcons.bookmark,
                          label: 'Save',
                          active: _feedSaved,
                          onPressed: () =>
                              setState(() => _feedSaved = !_feedSaved),
                        ),
                        const SizedBox(height: 8),
                        FeedActionButton(
                          icon: MxIcons.thumbsUp,
                          label: 'Like',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _Section(
          'Rating buttons',
          child: RatingButtons(
            value: _rating,
            onChanged: (r) => setState(() => _rating = r),
          ),
        ),
        _Section(
          'Segmented choice and group toggle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Text size'),
              const SizedBox(height: 10),
              SegmentedChoice<String>(
                options: const ['Small', 'Medium', 'Large'],
                value: _segment,
                labelOf: (s) => s,
                onChanged: (s) => setState(() => _segment = s),
              ),
              const SizedBox(height: 12),
              SegmentedChoice<String>(
                compact: true,
                options: const ['By era', 'By region'],
                value: _group,
                labelOf: (s) => s,
                onChanged: (s) => setState(() => _group = s),
              ),
            ],
          ),
        ),
        _Section(
          'Chips',
          padded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SuggestionChipRow(
                labels: const [
                  'Why did the Republic fall?',
                  'Who was Augustus?',
                ],
                onSelected: (_) {},
              ),
              const SuggestionChipRow(
                labels: ['Disabled (resting)', 'Who was Augustus?'],
                onSelected: null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    SourceChip(label: 'From lesson 4', onPressed: () {}),
                    const SizedBox(width: 8),
                    TopicTag(
                      label: 'World War II',
                      tint: GallerySamples.ww2.tint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Section(
          'Section header, label, kicker',
          padded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'For you'),
              const SizedBox(height: 12),
              SectionHeader(
                title: 'Your study list',
                trailing: MxTextButton(label: 'See all', onPressed: () {}),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Voice speed'),
                    SizedBox(height: 10),
                    Kicker('On this day · 21 November'),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Section(
          'Progress',
          child: Column(
            children: [
              MxProgressBar(value: 0.5, fill: roman.tint),
              const SizedBox(height: 12),
              const MxProgressBar(value: 2 / 6, quiz: true),
              const SizedBox(height: 12),
              const StepBar(current: 2),
              const SizedBox(height: 12),
              LessonSegments(count: 8, current: 4, tint: roman.tint),
            ],
          ),
        ),
        _Section(
          'Tabs: main nav and topic bar',
          padded: false,
          // Not at the screen bottom here, so drop the gesture-bar inset.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: Column(
              children: [
                MxNavBar(
                  items: MxNavItem.mainTabs,
                  currentIndex: _mainTab,
                  onSelected: (i) => setState(() => _mainTab = i),
                ),
                const SizedBox(height: 12),
                MxNavBar(
                  items: MxNavItem.topicTabs,
                  currentIndex: _topicTab,
                  onSelected: (i) => setState(() => _topicTab = i),
                ),
              ],
            ),
          ),
        ),
        _Section(
          'Top bars',
          padded: false,
          child: Column(
            children: [
              MxTabTopBar(
                title: 'Good evening',
                leading: const MxLogo(size: 30),
                trailing: MxIconButton(
                  icon: MxIcons.settings,
                  label: 'Settings',
                  onPressed: () {},
                ),
              ),
              MxPushedTopBar(
                title: 'Lesson 4 of 8',
                kicker: 'Roman history',
                kickerColor: roman.tint,
                onBack: () {},
              ),
            ],
          ),
        ),
        _Section(
          'Bottom sheet',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SecondaryButton(
                label: 'Open title sheet',
                onPressed: () => showMxBottomSheet<void>(
                  context: context,
                  theme: widget.theme,
                  banner: TintedGradient(bg: roman.bg, tint: roman.tint),
                  builder: (_) => const _SampleSheetBody(),
                ),
              ),
              const SizedBox(height: 12),
              const MxSheetFrame(child: _SampleSheetBody(compact: true)),
            ],
          ),
        ),
        _Section(
          'Answer options',
          child: Column(
            children: [
              for (final (i, label) in const [
                'Athens',
                'Carthage',
                'Sparta',
              ].indexed) ...[
                AnswerOption(
                  label: label,
                  state: _picked == null
                      ? AnswerState.idle
                      : i == 1
                      ? AnswerState.right
                      : (i == _picked ? AnswerState.wrong : AnswerState.idle),
                  onPressed: _picked == null
                      ? () => setState(() => _picked = i)
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              if (_picked != null) ...[
                const ExplanationBox(
                  'Carthage, in North Africa, was destroyed in 146 BCE.',
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Reset',
                  onPressed: () => setState(() => _picked = null),
                ),
              ],
            ],
          ),
        ),
        const _Section(
          'Cards',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ScoreTile(score: '5/6', topic: 'Roman history'),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ScoreTile(score: '4/6', topic: 'Ancient Greece'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              EmptyScores(),
              SizedBox(height: 12),
              InfoCard(
                kicker: 'On this day · 21 November',
                title: '1783: the first free balloon flight',
                body: 'Two men rose over Paris in a hot-air balloon and landed 25 minutes later.',
              ),
            ],
          ),
        ),
        _Section(
          'Settings rows and input',
          child: Column(
            children: [
              SettingsRow(
                label: 'Voice',
                value: 'Device default',
                onTap: () {},
              ),
              SettingsRow(
                label: 'Clear my data',
                value: 'Topics, scores, settings',
                destructive: true,
                onTap: () {},
              ),
              SettingsRow(
                label: 'Credits',
                showArrow: true,
                isLast: true,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              const MxTextField(hint: 'Email'),
              const SizedBox(height: 12),
              const MxTextField(hint: 'Ask about the Roman Empire', radius: 26),
            ],
          ),
        ),
        const _Section(
          'Loading states',
          padded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterRowSkeleton(posterWidth: 110),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextSkeleton(),
              ),
              SizedBox(height: 60, child: LoadingState()),
            ],
          ),
        ),
        _Section(
          'Error, empty and offline states',
          padded: false,
          child: Column(
            children: [
              const OfflineBanner(),
              const SizedBox(height: 20),
              ErrorState(offline: true, onRetry: () {}),
              EmptyState(
                title: 'Nothing here yet',
                body: 'Add a topic from the library and it will wait for you here.',
                art: TintedGradient(
                  bg: const Color(0xFF1E3A5F),
                  tint: const Color(0xFF6FB1E0),
                ),
                actionLabel: 'Browse the library',
                onAction: () {},
              ),
            ],
          ),
        ),
        const _Section('Logo', child: MxLockup()),
      ],
    );
  }
}

class _SampleSheetBody extends StatefulWidget {
  const _SampleSheetBody({this.compact = false});
  final bool compact;

  @override
  State<_SampleSheetBody> createState() => _SampleSheetBodyState();
}

class _SampleSheetBodyState extends State<_SampleSheetBody> {
  Rating? _rating;
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    const roman = GallerySamples.roman;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '94% match ',
                style: MxText.buttonS.copyWith(color: c.accentText),
              ),
              TextSpan(
                text: 'because you liked Ancient Greece',
                style: MxText.sub.copyWith(
                  fontWeight: FontWeight.w500,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SheetLettering(lines: roman.lines, kind: roman.lettering),
        if (!widget.compact) ...[
          const SizedBox(height: 12),
          Text(
            'From a village on seven hills to the biggest empire of the ancient world.',
            style: MxText.bodyL.copyWith(color: c.text),
          ),
          const SizedBox(height: 12),
          Text(
            '8 lessons · 48 min',
            style: MxText.meta.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 12),
          RatingButtons(
            value: _rating,
            onChanged: (r) => setState(() => _rating = r),
          ),
          const SizedBox(height: 12),
          TintButton(label: 'Start', tint: roman.tint, onPressed: () {}),
          const SizedBox(height: 12),
          AccentOutlineButton.studyList(
            added: _added,
            onPressed: () => setState(() => _added = !_added),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child, this.padded = true});

  final String title;
  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MxSpace.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Kicker(title),
          ),
          const SizedBox(height: 12),
          padded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: child,
                )
              : child,
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors});
  final MxColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final roles = {
      'bg': c.bg,
      'surface': c.surface,
      'surfaceRaised': c.surfaceRaised,
      'text': c.text,
      'textMuted': c.textMuted,
      'accent': c.accent,
      'accentText': c.accentText,
      'accentContainer': c.accentContainer,
      'onAccent': c.onAccent,
      'success': c.success,
      'successContainer': c.successContainer,
      'error': c.error,
      'errorContainer': c.errorContainer,
      'divider': c.divider,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in roles.entries)
          SizedBox(
            width: 82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: e.value,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.divider),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MxText.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final styles = {
      'display 34/900': MxText.display,
      'lessonTitle 30/900': MxText.lessonTitle,
      'screenTitle 26/900': MxText.screenTitle,
      'cardTitle 22/900': MxText.cardTitle,
      'section 19/800': MxText.section,
      'buttonL 17/800': MxText.buttonL,
      'bodyL 16/500': MxText.bodyL,
      'body 15/500': MxText.body,
      'sub 13/600': MxText.sub,
      'CAPTION 12/600': MxText.caption,
    };
    final reading = Theme.of(context).extension<MxReading>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in styles.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(e.key, style: e.value.copyWith(color: c.text)),
          ),
        Text(
          'Reader ${reading.size.label} ${reading.size.readerSize.round()}: '
          'For centuries, Roman soldiers were citizens who went home after a war.',
          style: reading.paragraph.copyWith(color: c.text),
        ),
      ],
    );
  }
}
