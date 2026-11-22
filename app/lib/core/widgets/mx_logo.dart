// "The disc" logo (DESIGN_SPEC 10.1). Colour defaults to accentText (11.10).
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Product name, kept as one constant while the name is open (11.23).
const kAppName = 'Maximus';

class MxLogo extends StatelessWidget {
  const MxLogo({super.key, this.size = 30, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kAppName,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _DiscPainter(color ?? context.mx.accentText),
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(const Offset(50, 50), 42, ring);
    // M50 18 A32 32 0 0 0 50 82z: left half disc.
    final half = Path()
      ..moveTo(50, 18)
      ..arcToPoint(
        const Offset(50, 82),
        radius: const Radius.circular(32),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(half, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DiscPainter old) => old.color != color;
}

/// Mark 52 + "Maximus" Figtree 700 34, -0.02em, gap 16.
class MxLockup extends StatelessWidget {
  const MxLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MxLogo(size: 52),
        const SizedBox(width: 16),
        Text(
          kAppName,
          style: TextStyle(
            fontFamily: MxFonts.figtree,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.02 * 34,
            color: c.text,
          ),
        ),
      ],
    );
  }
}
