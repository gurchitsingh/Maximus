// Top app bars (DESIGN_SPEC 7.9). Library and Feed have none.
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'mx_icon.dart';

/// Tab screens: h64, pad 0 12 0 20. Optional leading (Home logo) and
/// trailing (Settings button).
class MxTabTopBar extends StatelessWidget {
  const MxTabTopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MxSpace.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MxText.screenTitle.copyWith(color: context.mx.text),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Pushed screens: h64, pad 0 12 0 4, Back + title, or Back + kicker and
/// subtitle (topic screens).
class MxPushedTopBar extends StatelessWidget {
  const MxPushedTopBar({
    super.key,
    required this.title,
    this.kicker,
    this.kickerColor,
    this.onBack,
    this.trailing,
  });

  /// Screen title, or the subtitle when [kicker] is set.
  final String title;

  /// Topic name in caps, coloured with the topic tint.
  final String? kicker;
  final Color? kickerColor;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SizedBox(
      height: MxSpace.topBarHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 12),
        child: Row(
          children: [
            MxIconButton(
              icon: MxIcons.chevronLeft,
              label: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: kicker == null
                  ? Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MxText.screenTitle.copyWith(color: c.text),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kicker!.toUpperCase(),
                          maxLines: 1,
                          style: MxText.kicker.copyWith(
                            color: kickerColor ?? c.accentText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MxText.rowTitleL.copyWith(color: c.text),
                        ),
                      ],
                    ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
