import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.showText = true});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.asset(
            'assets/app_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return CustomPaint(
                size: Size.square(size),
                painter: _FallbackLogoPainter(),
              );
            },
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.2),
          Text(
            '+Balance',
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _FallbackLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()..color = AppTheme.primary;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h * 0.28),
    );
    canvas.drawRRect(bgRect, bg);

    final plus = Paint()
      ..color = AppTheme.secondary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.13;

    final cx = w * 0.30;
    final cy = h * 0.30;
    final plusLen = h * 0.22;

    canvas.drawLine(Offset(cx - plusLen, cy), Offset(cx + plusLen, cy), plus);
    canvas.drawLine(Offset(cx, cy - plusLen), Offset(cx, cy + plusLen), plus);

    final stroke = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.10;

    final bx = w * 0.62;
    final top = h * 0.22;
    final bottom = h * 0.78;
    final mid = h * 0.50;

    canvas.drawLine(Offset(bx, top), Offset(bx, bottom), stroke);

    final topArc = Path()
      ..moveTo(bx, top)
      ..quadraticBezierTo(bx + h * 0.32, top, bx + h * 0.32, (top + mid) / 2)
      ..quadraticBezierTo(bx + h * 0.32, mid, bx, mid);
    canvas.drawPath(topArc, stroke);

    final botArc = Path()
      ..moveTo(bx, mid)
      ..quadraticBezierTo(bx + h * 0.36, mid, bx + h * 0.36, (mid + bottom) / 2)
      ..quadraticBezierTo(bx + h * 0.36, bottom, bx, bottom);
    canvas.drawPath(botArc, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}