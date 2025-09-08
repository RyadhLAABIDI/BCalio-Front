import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SpiderWebPainter extends CustomPainter {
  final double progress;
  final Path? titlePath;
  final List<Offset> points = [];
  final List<bool> showUserIcon = [];
  final double colorShift = 0.02;

  final List<Color> allowedColors = const [
    Color(0xFF00FFEA),
    Color(0xFF00CFFF),
    Color(0xFF00A896),
    Color(0xFF00FFC2),
    Color(0xFF0A0E2D),
    Colors.cyanAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Color(0xFF00FF00),
    Color(0xFF0044FF),
  ];

  SpiderWebPainter(this.progress, {this.titlePath}) {
    final double width  = ui.window.physicalSize.width / ui.window.devicePixelRatio;
    final double height = ui.window.physicalSize.height / ui.window.devicePixelRatio;

    final int cols = 14;
    final int rows = 24;
    final double spacingX = width / cols;
    final double spacingY = height / rows;

    final random = Random(12345);
    for (int row = 0; row <= rows; row++) {
      for (int col = 0; col <= cols; col++) {
        double x = col * spacingX;
        double y = row * spacingY;

        double dx = sin(progress * 2 * pi + col) * 6;
        double dy = cos(progress * 2 * pi + row) * 6;

        points.add(Offset(x + dx, y + dy));
        showUserIcon.add(random.nextDouble() > 0.80);
      }
    }
  }

  Color getDynamicColor(double offset) {
    final base = (progress * colorShift * 100 + offset);
    final baseIndex = base.floor() % allowedColors.length;
    final nextIndex = (baseIndex + 1) % allowedColors.length;
    final t = base % 1;
    return Color.lerp(allowedColors[baseIndex], allowedColors[nextIndex], t)!.withOpacity(0.9);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (final p1 in points) {
      for (final p2 in points) {
        final dist = (p1 - p2).distance;
        if (dist < 100) {
          final opacity = 1 - (dist / 100);
          if ((progress * 10 + dist).floor() % 20 < 10) {
            linePaint.color = getDynamicColor(dist).withOpacity(opacity);
            canvas.drawLine(p1, p2, linePaint);
          }
        }
      }
    }

    final Paint pointPaint = Paint()..style = PaintingStyle.fill;
    final Paint glowPaint  = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    const icon = Icons.person;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final pulse = 1.5 + sin(progress * 2 * pi + i) * 0.5;
      final baseColor = getDynamicColor(i.toDouble());

      pointPaint.color = baseColor.withOpacity(0.9);
      glowPaint.color  = baseColor.withOpacity(0.7);

      canvas.drawCircle(p, pulse, pointPaint);

      if (showUserIcon[i]) {
        canvas.drawCircle(p, 14, glowPaint);
        final brightColor = baseColor.withOpacity(1.0);

        final textPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: 28,
              fontFamily: 'MaterialIcons',
              color: brightColor,
              shadows: [
                Shadow(blurRadius: 6, color: brightColor.withOpacity(0.8)),
                Shadow(blurRadius: 14, color: brightColor.withOpacity(0.7)),
                Shadow(blurRadius: 30, color: brightColor.withOpacity(0.5)),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, p - Offset(textPainter.width / 2, textPainter.height / 2));
      }
    }

    if (titlePath != null) {
      final ui.PathMetrics metrics = titlePath!.computeMetrics();
      final Paint pathPaint = Paint()
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final metric in metrics) {
        for (double i = 0; i < metric.length; i += 16) {
          final pos = metric.getTangentForOffset(i)?.position;
          if (pos != null) {
            final c = getDynamicColor(i);
            pathPaint.color = c.withOpacity(0.9);
            canvas.drawCircle(pos, 1.6, pathPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
