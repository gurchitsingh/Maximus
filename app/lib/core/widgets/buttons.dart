// Buttons from DESIGN_SPEC 7.1. Undesigned states use the 11.14 defaults:
// pressed = 8% text overlay on outline/ghost, darken on fills; focus shows a
// 2 dp accent ring; disabled = opacity 0.4 and taps ignored.
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'mx_icon.dart';

/// Shared tap surface: stadium-shaped ink, pressed overlay, focus ring,
/// disabled opacity. Every button below is built on it.
class MxPressable extends StatefulWidget {
  const MxPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.fill,
    this.border,
    this.borderRadius,
    this.overlay,
    this.semanticLabel,
    this.selected,
    this.toggled,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color? fill;
  final BorderSide? border;

  /// Null = stadium (fully round ends).
  final BorderRadius? borderRadius;

  /// Pressed overlay colour; defaults per fill (darken) or text (8%).
  final Color? overlay;
  final String? semanticLabel;
  final bool? selected;

  /// For toggle buttons (aria-pressed in the prototype).
  final bool? toggled;

  @override
  State<MxPressable> createState() => _MxPressableState();
}

class _MxPressableState extends State<MxPressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final enabled = widget.onPressed != null;
    final ShapeBorder shape = widget.borderRadius == null
        ? StadiumBorder(side: widget.border ?? BorderSide.none)
        : RoundedRectangleBorder(
            borderRadius: widget.borderRadius!,
            side: widget.border ?? BorderSide.none,
          );
    final overlay =
        widget.overlay ??
        (widget.fill != null && widget.fill!.a > 0.5
            ? const Color(0x24000000)
            : c.text.withValues(alpha: 0.08));

    Widget body = Material(
      color: widget.fill ?? Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onPressed,
        onFocusChange: (f) => setState(() => _focused = f),
        customBorder: shape,
        overlayColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed) ? overlay : null,
        ),
        child: widget.child,
      ),
    );

    if (_focused) {
      body = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: widget.borderRadius == null
              ? StadiumBorder(side: BorderSide(color: c.accent, width: 2))
              : RoundedRectangleBorder(
                  borderRadius: widget.borderRadius!,
                  side: BorderSide(color: c.accent, width: 2),
                ),
        ),
        child: body,
      );
    }

    return Semantics(
      // Own node, so TalkBack never merges a button with its neighbours.
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: Opacity(opacity: enabled ? 1 : 0.4, child: body),
    );
  }
}

Widget _labelRow(
  String label,
  TextStyle style,
  MxIcons? icon,
  double iconSize,
  Color color, {
  bool trailingIcon = false,
  double gap = 8,
}) {
  final text = Text(label, style: style.copyWith(color: color), maxLines: 1);
  if (icon == null) return text;
  final i = MxIcon(icon, size: iconSize, color: color);
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: trailingIcon
        ? [Flexible(child: text), SizedBox(width: gap), i]
        : [i, SizedBox(width: gap), Flexible(child: text)],
  );
}

/// Primary: h56, full width, accent fill, onAccent text, buttonL.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final MxIcons? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: MxPressable(
        onPressed: onPressed,
        fill: c.accent,
        child: Center(
          child: _labelRow(label, MxText.buttonL, icon, 20, c.onAccent),
        ),
      ),
    );
  }
}

/// Secondary outline neutral: h52 (h56 for provider buttons), 2 dp divider.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final MxIcons? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: MxPressable(
        onPressed: onPressed,
        border: BorderSide(color: c.divider, width: 2),
        child: Center(
          child: _labelRow(label, MxText.buttonM, icon, 22, c.text),
        ),
      ),
    );
  }
}

/// Accent outline toggle: "Add to study list" ↔ "Added to study list".
class AccentOutlineButton extends StatelessWidget {
  const AccentOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.toggled,
  });

  final String label;
  final VoidCallback? onPressed;
  final MxIcons? icon;
  final bool? toggled;

  /// The title sheet's study-list toggle.
  factory AccentOutlineButton.studyList({
    Key? key,
    required bool added,
    required VoidCallback? onPressed,
  }) => AccentOutlineButton(
    key: key,
    label: added ? 'Added to study list' : 'Add to study list',
    icon: added ? MxIcons.check : MxIcons.plus,
    toggled: added,
    onPressed: onPressed,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: MxPressable(
        onPressed: onPressed,
        toggled: toggled,
        border: BorderSide(color: c.accentText, width: 2),
        child: Center(
          child: _labelRow(label, MxText.buttonM, icon, 22, c.accentText),
        ),
      ),
    );
  }
}

/// Add (match card): filled "Add" ↔ outlined "Added", with the 220 ms pop.
class AddButton extends StatefulWidget {
  const AddButton({super.key, required this.added, required this.onPressed});

  final bool added;
  final VoidCallback? onPressed;

  @override
  State<AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<AddButton>
    with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: MxMotion.addedPop,
  );
  late final _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: MxMotion.addedPopScale),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: MxMotion.addedPopScale, end: 1.0),
      weight: 1,
    ),
  ]).animate(CurvedAnimation(parent: _pop, curve: MxMotion.standard));

  @override
  void didUpdateWidget(AddButton old) {
    super.didUpdateWidget(old);
    if (!old.added && widget.added && !MxMotion.reduced(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final added = widget.added;
    final color = added ? c.accentText : c.onAccent;
    return ScaleTransition(
      scale: _scale,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: MxPressable(
          onPressed: widget.onPressed,
          toggled: added,
          fill: added ? null : c.accent,
          border: added ? BorderSide(color: c.accentText, width: 2) : null,
          child: Center(
            child: _labelRow(
              added ? 'Added' : 'Add',
              MxText.buttonS,
              added ? MxIcons.check : MxIcons.plus,
              18,
              color,
              gap: 6,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tint button: h56, topic tint fill, dark ink (11.17), optional play icon.
class TintButton extends StatelessWidget {
  const TintButton({
    super.key,
    required this.label,
    required this.tint,
    required this.onPressed,
    this.icon = MxIcons.play,
  });

  final String label;
  final Color tint;
  final VoidCallback? onPressed;
  final MxIcons? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: MxPressable(
        onPressed: onPressed,
        fill: tint,
        child: Center(
          child: _labelRow(label, MxText.buttonL, icon, 18, MxFixed.inkOnTint),
        ),
      ),
    );
  }
}

enum PillSize { resume, hero, goDeeper }

/// Pill CTA on artwork: Resume (h40), hero Start (h48), Go deeper (h48).
class PillCta extends StatelessWidget {
  const PillCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PillSize.hero,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillSize size;

  /// Topic tint for Resume and hero Start. Go deeper is always bronze.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final (h, pad, font, iconSize, icon, trailing) = switch (size) {
      PillSize.resume => (40.0, 16.0, 14.0, 14.0, MxIcons.play, false),
      PillSize.hero => (48.0, 22.0, 16.0, 16.0, MxIcons.play, false),
      PillSize.goDeeper => (48.0, 20.0, 15.0, 18.0, MxIcons.arrowRight, true),
    };
    final fill = size == PillSize.goDeeper
        ? MxFixed.ring
        : (tint ?? MxFixed.ring);
    return SizedBox(
      height: h,
      child: MxPressable(
        onPressed: onPressed,
        fill: fill,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Center(
            widthFactor: 1,
            child: _labelRow(
              label,
              MxText.buttonS.copyWith(fontSize: font),
              icon,
              iconSize,
              MxFixed.inkOnTint,
              trailingIcon: trailing,
              gap: 6,
            ),
          ),
        ),
      ),
    );
  }
}

enum MxTextButtonStyle { skip, link, toggleLink }

/// Text button: h48, transparent.
class MxTextButton extends StatelessWidget {
  const MxTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = MxTextButtonStyle.link,
  });

  final String label;
  final VoidCallback? onPressed;
  final MxTextButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (TextStyle s, Color color) = switch (style) {
      MxTextButtonStyle.skip => (MxText.skip, c.textMuted),
      MxTextButtonStyle.link => (MxText.chip, c.accentText),
      MxTextButtonStyle.toggleLink => (MxText.segment, c.accentText),
    };
    return SizedBox(
      height: 48,
      child: MxPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: s.copyWith(color: color)),
          ),
        ),
      ),
    );
  }
}

/// Icon button: 48x48 transparent. Label is required for screen readers.
class MxIconButton extends StatelessWidget {
  const MxIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 24,
    this.color,
  });

  final MxIcons icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: MxPressable(
        onPressed: onPressed,
        semanticLabel: label,
        child: Center(
          child: MxIcon(icon, size: size, color: color ?? context.mx.text),
        ),
      ),
    );
  }
}

/// Filled circle: 48 (read aloud) or 52 (chat send), accent fill.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.diameter = 48,
  });

  final MxIcons icon;
  final String label;
  final VoidCallback? onPressed;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SizedBox.square(
      dimension: diameter,
      child: MxPressable(
        onPressed: onPressed,
        fill: c.accent,
        semanticLabel: label,
        child: Center(
          child: MxIcon(
            icon,
            size: diameter >= 52 ? 22 : 20,
            color: c.onAccent,
          ),
        ),
      ),
    );
  }
}

/// Feed side action: 52 circle on artwork, L1 shadow. Active fills with
/// accent (11.14 default; not designed).
class FeedActionButton extends StatelessWidget {
  const FeedActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final MxIcons icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: MxElevation.l1,
      ),
      child: SizedBox.square(
        dimension: 52,
        child: MxPressable(
          onPressed: onPressed,
          fill: active ? MxFixed.ring : MxFixed.feedActionBg,
          semanticLabel: label,
          toggled: active,
          child: Center(
            child: MxIcon(
              icon,
              size: 24,
              color: active ? MxFixed.inkOnTint : MxFixed.textOnArt,
            ),
          ),
        ),
      ),
    );
  }
}
