import 'package:flutter/material.dart';

/// Official Ridin Brand Logo Widget - Direction A (The Connected Monogram)
class RidinLogoIcon extends StatelessWidget {
  final double size;
  final bool showShadow;

  const RidinLogoIcon({
    super.key,
    this.size = 72,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Obsidian Navy
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _RidinMonogramPainter(),
        ),
      ),
    );
  }
}

class _RidinMonogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1024.0;
    canvas.scale(scale, scale);

    final amberPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final whiteFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final navyFill = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final amberFill = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;

    // Outer Radar Wave
    amberPaint.strokeWidth = 36;
    final outerRect = Rect.fromCircle(center: const Offset(640, 430), radius: 180);
    canvas.drawArc(outerRect, -3.14159 / 2, 3.14159 / 2, false, amberPaint);

    // Inner Radar Wave
    amberPaint.strokeWidth = 32;
    final innerRect = Rect.fromCircle(center: const Offset(640, 430), radius: 100);
    canvas.drawArc(innerRect, -3.14159 / 2, 3.14159 / 2, false, amberPaint);

    // Radar Center Pulse Dot
    canvas.drawCircle(const Offset(640, 430), 22, amberFill);

    // Monogram 'R' Vertical Stem (Pillar)
    final rRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(230, 250, 120, 524),
      const Radius.circular(24),
    );
    canvas.drawRRect(rRRect, whiteFill);

    // Upper Loop (Transit Roof & Frame)
    final upperPath = Path()
      ..moveTo(330, 250)
      ..lineTo(530, 250)
      ..cubicTo(640, 250, 710, 320, 710, 420)
      ..cubicTo(710, 515, 640, 580, 530, 580)
      ..lineTo(330, 580)
      ..close();
    canvas.drawPath(upperPath, whiteFill);

    // Negative Space (Bus Windshield)
    final windshieldPath = Path()
      ..moveTo(350, 340)
      ..lineTo(510, 340)
      ..cubicTo(560, 340, 595, 375, 595, 415)
      ..cubicTo(595, 455, 560, 490, 510, 490)
      ..lineTo(350, 490)
      ..close();
    canvas.drawPath(windshieldPath, navyFill);

    // Amber Cabin/Bumper Horizon Light
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(380, 450, 100, 18), const Radius.circular(9)),
      amberFill,
    );

    // Dynamic Diagonal Leg (Forward Road Pathway)
    final legPath = Path()
      ..moveTo(450, 540)
      ..lineTo(650, 750)
      ..cubicTo(665, 765, 690, 774, 715, 774)
      ..lineTo(730, 774)
      ..cubicTo(760, 774, 775, 745, 755, 725)
      ..lineTo(560, 520)
      ..close();
    canvas.drawPath(legPath, whiteFill);

    // Amber Speed Curve Accent
    final amberCurvePath = Path()
      ..moveTo(580, 774)
      ..lineTo(680, 774)
      ..cubicTo(715, 774, 735, 750, 715, 725)
      ..lineTo(610, 615)
      ..lineTo(530, 690)
      ..close();
    canvas.drawPath(amberCurvePath, amberFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full Horizontal Brand Lockup (Icon + Wordmark)
class RidinHorizontalLogo extends StatelessWidget {
  final double iconSize;
  final bool isDark;

  const RidinHorizontalLogo({
    super.key,
    this.iconSize = 42,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RidinLogoIcon(size: iconSize, showShadow: false),
        SizedBox(width: iconSize * 0.3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'r',
                  style: TextStyle(
                    fontSize: iconSize * 0.65,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Text(
                      'i',
                      style: TextStyle(
                        fontSize: iconSize * 0.65,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Positioned(
                      top: iconSize * 0.08,
                      child: Container(
                        width: iconSize * 0.12,
                        height: iconSize * 0.12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'd',
                  style: TextStyle(
                    fontSize: iconSize * 0.65,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Text(
                      'i',
                      style: TextStyle(
                        fontSize: iconSize * 0.65,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Positioned(
                      top: iconSize * 0.08,
                      child: Container(
                        width: iconSize * 0.12,
                        height: iconSize * 0.12,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'n',
                  style: TextStyle(
                    fontSize: iconSize * 0.65,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Text(
              'INTELLIGENT FLEET RADAR',
              style: TextStyle(
                fontSize: iconSize * 0.18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
