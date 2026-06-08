import 'package:flutter/material.dart';

/// The stonechat brand mark: a cream chat bubble on a slate "stone" field, with
/// two amber peers linked inside — the offline, peer-to-peer idea. Drawn in code
/// so it scales crisply and renders to the app icon. Deliberately avoids the
/// Bluetooth figure mark (a Bluetooth SIG trademark).
class StonechatMark extends StatelessWidget {
  const StonechatMark({this.size = 96, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: StonechatMarkPainter());
}

class StonechatMarkPainter extends CustomPainter {
  static const _slateTop = Color(0xFF49566B);
  static const _slateBottom = Color(0xFF272E3A);
  static const _cream = Color(0xFFF2EFE8);
  static const _amber = Color(0xFFE0954C);
  static const _peerLine = Color(0xFFC9853F);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double fx, double fy) => Offset(fx * s, fy * s);

    // Slate stone background.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_slateTop, _slateBottom],
        ).createShader(Offset.zero & size),
    );

    final cream = Paint()
      ..color = _cream
      ..isAntiAlias = true;

    // Chat bubble body + a tail at the bottom-left, unioned in one pass.
    final bubble = Path()
      ..fillType = PathFillType.nonZero
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0.17 * s, 0.23 * s, 0.83 * s, 0.63 * s),
          Radius.circular(0.13 * s),
        ),
      )
      ..moveTo(p(0.30, 0.60).dx, p(0.30, 0.60).dy)
      ..lineTo(p(0.27, 0.78).dx, p(0.27, 0.78).dy)
      ..lineTo(p(0.46, 0.61).dx, p(0.46, 0.61).dy)
      ..close();
    canvas.drawPath(bubble, cream);

    // Two linked peers inside the bubble.
    final cy = 0.43 * s;
    final lx = 0.37 * s;
    final rx = 0.63 * s;
    canvas.drawLine(
      Offset(lx, cy),
      Offset(rx, cy),
      Paint()
        ..color = _peerLine
        ..strokeWidth = 0.035 * s
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = _amber;
    canvas.drawCircle(Offset(lx, cy), 0.06 * s, dot);
    canvas.drawCircle(Offset(rx, cy), 0.06 * s, dot);

    // Outward-facing "signal" arcs emanating from each peer (left peer radiates
    // left, right peer radiates right) — a wireless hint without a face look.
    final arc = Paint()
      ..color = _peerLine.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018 * s
      ..strokeCap = StrokeCap.round;
    void waves(double cx, double startAngle) {
      for (final r in [0.105, 0.15]) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r * s),
          startAngle,
          1.4,
          false,
          arc,
        );
      }
    }
    waves(lx, 2.45); // left peer → arcs open to the left
    waves(rx, -0.7); // right peer → arcs open to the right
  }

  @override
  bool shouldRepaint(StonechatMarkPainter oldDelegate) => false;
}
