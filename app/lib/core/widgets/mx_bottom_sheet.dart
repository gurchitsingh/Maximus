// Modal bottom sheet shell (DESIGN_SPEC 7.10): backdrop 0.62, top radius
// 28, surface, divider border, L2 shadow, max 96% height, scrolls.
// Optional banner (h200 topic art) with the drag handle on top of it.
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

Future<T?> showMxBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Widget? banner,

  /// Overrides the route theme (the gallery previews other themes).
  ThemeData? theme,

  /// Cover the whole screen, including a shell's bottom bar.
  bool useRootNavigator = false,
}) {
  final reduced = MxMotion.reduced(context);
  Widget frame(BuildContext ctx) =>
      MxSheetFrame(banner: banner, child: builder(ctx));
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: MxFixed.sheetBackdrop,
    elevation: 0,
    sheetAnimationStyle: reduced ? AnimationStyle.noAnimation : null,
    builder: (ctx) => theme == null
        ? frame(ctx)
        : Theme(
            data: theme,
            child: Builder(builder: frame),
          ),
  );
}

/// The same sheet as a router page, for routes like `/sheet/:titleId`
/// (CONTRACTS 8.3: a modal sheet page on the root navigator).
class MxSheetPage<T> extends Page<T> {
  const MxSheetPage({
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    required this.builder,
    this.banner,
  });

  final WidgetBuilder builder;
  final Widget? banner;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    settings: this,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    modalBarrierColor: MxFixed.sheetBackdrop,
    elevation: 0,
    sheetAnimationStyle: MxMotion.reduced(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (ctx) => MxSheetFrame(banner: banner, child: builder(ctx)),
  );
}

/// The visual frame of a sheet. Separate so the gallery can show it inline.
class MxSheetFrame extends StatelessWidget {
  const MxSheetFrame({super.key, required this.child, this.banner});

  final Widget child;
  final Widget? banner;

  static const radius = BorderRadius.vertical(
    top: Radius.circular(MxRadius.sheet),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final maxH = MediaQuery.sizeOf(context).height * 0.96;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(color: c.divider),
          boxShadow: MxElevation.l2,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (banner != null)
                  SizedBox(
                    height: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        banner!,
                        const Align(
                          alignment: Alignment.topCenter,
                          child: _DragHandle(color: MxFixed.dragHandleOnArt),
                        ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: _DragHandle(
                      color: c.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                Padding(
                  // Keep the last button clear of the gesture bar.
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    22 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
