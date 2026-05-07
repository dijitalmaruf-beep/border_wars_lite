import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class PremiumBackground extends StatelessWidget {
  const PremiumBackground({
    required this.child,
    this.showGlobe = false,
    super.key,
  });

  final Widget child;
  final bool showGlobe;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF001628),
            AppColors.premiumBackground,
            Color(0xFF00101B),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _PremiumBackgroundPainter(showGlobe: showGlobe)),
          child,
        ],
      ),
    );
  }
}

class _PremiumBackgroundPainter extends CustomPainter {
  const _PremiumBackgroundPainter({required this.showGlobe});

  final bool showGlobe;

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.44);
    const stars = <Offset>[
      Offset(0.08, 0.11),
      Offset(0.18, 0.08),
      Offset(0.32, 0.15),
      Offset(0.72, 0.10),
      Offset(0.88, 0.17),
      Offset(0.13, 0.78),
      Offset(0.82, 0.82),
      Offset(0.48, 0.07),
      Offset(0.62, 0.18),
      Offset(0.25, 0.90),
    ];
    for (final star in stars) {
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        1.1,
        starPaint,
      );
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.premiumCyan.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.74, size.height * 0.18),
          radius: size.width * 0.42,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.18),
      size.width * 0.42,
      glowPaint,
    );

    if (!showGlobe) {
      return;
    }

    final globeCenter = Offset(size.width * 0.52, size.height * 0.30);
    final globeRadius = size.width * 0.72;
    final globeRect = Rect.fromCircle(center: globeCenter, radius: globeRadius);
    final globePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.30, -0.22),
        colors: <Color>[
          const Color(0xFF315E73).withValues(alpha: 0.95),
          const Color(0xFF062437).withValues(alpha: 0.82),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.58, 1.0],
      ).createShader(globeRect);
    canvas.drawCircle(globeCenter, globeRadius, globePaint);

    final horizonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.transparent,
          AppColors.premiumCyan.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.82),
          Colors.transparent,
        ],
      ).createShader(globeRect);
    canvas.drawArc(
      Rect.fromCircle(center: globeCenter, radius: globeRadius * 0.99),
      math.pi * 1.03,
      math.pi * 0.62,
      false,
      horizonPaint,
    );

    final landPaint = Paint()
      ..color = const Color(0xFF8B7B52).withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final land = Path()
      ..moveTo(size.width * 0.15, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.18,
        size.width * 0.50,
        size.height * 0.27,
      )
      ..quadraticBezierTo(
        size.width * 0.41,
        size.height * 0.38,
        size.width * 0.24,
        size.height * 0.39,
      )
      ..close();
    canvas.drawPath(land, landPaint);
  }

  @override
  bool shouldRepaint(covariant _PremiumBackgroundPainter oldDelegate) {
    return oldDelegate.showGlobe != showGlobe;
  }
}
