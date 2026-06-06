import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo oficial de la app dibujado con [CustomPainter] (no usa imagen de Flutter).
///
/// Muestra una marca en forma de "B" estilizada con un signo "+" verde
/// (símbolo de "más balance") y el texto "+Balance" al lado.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48, this.showText = true});

  /// Tamaño (lado) del ícono del logo.
  final double size;

  /// Si es `true` muestra también el texto "+Balance" al lado.
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _LogoPainter(),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.25),
          Text(
            '+Balance',
            style: TextStyle(
              fontSize: size * 0.55,
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

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fondo redondeado (moneda / tarjeta)
    final bg = Paint()..color = AppTheme.primary;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(h * 0.28),
    );
    canvas.drawRRect(bgRect, bg);

    // Signo "+" en verde (símbolo de "más")
    final plus = Paint()
      ..color = AppTheme.secondary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * 0.13;

    final cx = w * 0.30;
    final cy = h * 0.30;
    final plusLen = h * 0.22;

    canvas.drawLine(Offset(cx - plusLen, cy), Offset(cx + plusLen, cy), plus);
    canvas.drawLine(Offset(cx, cy - plusLen), Offset(cx, cy + plusLen), plus);

    // "B" estilizada (línea vertical + dos bucles)
    final stroke = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.10;

    final bx = w * 0.62;
    final top = h * 0.22;
    final bottom = h * 0.78;
    final mid = h * 0.50;

    // Línea vertical
    canvas.drawLine(Offset(bx, top), Offset(bx, bottom), stroke);

    // Bucle superior
    final topArc = Path()
      ..moveTo(bx, top)
      ..quadraticBezierTo(bx + h * 0.32, top, bx + h * 0.32, (top + mid) / 2)
      ..quadraticBezierTo(bx + h * 0.32, mid, bx, mid);
    canvas.drawPath(topArc, stroke);

    // Bucle inferior
    final botArc = Path()
      ..moveTo(bx, mid)
      ..quadraticBezierTo(bx + h * 0.36, mid, bx + h * 0.36, (mid + bottom) / 2)
      ..quadraticBezierTo(bx + h * 0.36, bottom, bx, bottom);
    canvas.drawPath(botArc, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
