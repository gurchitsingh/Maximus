// Loading, error, empty and offline states. Loading and error are not
// designed (11.14): skeletons use surfaceRaised blocks with a slow pulse
// (still under reduced motion); errors reuse the empty-state layout (7.23).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'mx_icon.dart';

/// Pulsing placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MxMotion.reduced(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.mx.surfaceRaised;
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A row of poster-shaped skeletons (Home/Library while the catalogue loads).
class PosterRowSkeleton extends StatelessWidget {
  const PosterRowSkeleton({super.key, this.posterWidth = 128, this.count = 3});

  final double posterWidth;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        height: posterWidth * 1.5,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: MxSpace.gutter),
          itemCount: count,
          separatorBuilder: (_, _) =>
              const SizedBox(width: MxSpace.posterRowGap),
          itemBuilder: (_, _) => Skeleton(
            width: posterWidth,
            height: posterWidth * 1.5,
            radius: MxRadius.poster(posterWidth),
          ),
        ),
      ),
    );
  }
}

/// Text-block skeleton (lesson body, sheet brief).
class TextSkeleton extends StatelessWidget {
  const TextSkeleton({super.key, this.lines = 4});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++) ...[
            FractionallySizedBox(
              widthFactor: i == lines - 1 ? 0.6 : 1,
              child: const Skeleton(height: 14),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Full-area loading for whole screens. Prefer skeletons where layout is known.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading',
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: context.mx.accent,
            backgroundColor: context.mx.surfaceRaised,
          ),
        ),
      ),
    );
  }
}

/// Empty state (7.23): art 150 r24 · title · body · full-width primary.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.art,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final Widget? art;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 36, 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(MxRadius.emptyArt),
              child: SizedBox.square(dimension: 150, child: art),
            ),
            const SizedBox(height: 18),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: MxText.emptyTitle.copyWith(color: c.text),
          ),
          const SizedBox(height: 18),
          Text(
            body,
            textAlign: TextAlign.center,
            style: MxText.body.copyWith(color: c.textMuted),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Content error with retry. Same layout as the empty state, with an icon
/// instead of art and an outline retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.body = 'We could not load this. Check your connection and try again.',
    this.offline = false,
    this.onRetry,
  });

  final String title;
  final String body;

  /// Shows the wifi-off icon instead of the question mark.
  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 36, 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MxIcon(
            offline ? MxIcons.wifiOff : MxIcons.quiz,
            size: 40,
            color: c.textMuted,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: MxText.emptyTitle.copyWith(color: c.text),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: MxText.body.copyWith(color: c.textMuted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            SecondaryButton(label: 'Try again', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

/// Offline banner (7.14): full width, surfaceRaised, wifi-off + message.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = 'You are offline. Chat needs a connection.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: c.surfaceRaised,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            MxIcon(MxIcons.wifiOff, size: 18, color: c.text),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: MxText.hint.copyWith(color: c.text)),
            ),
          ],
        ),
      ),
    );
  }
}
