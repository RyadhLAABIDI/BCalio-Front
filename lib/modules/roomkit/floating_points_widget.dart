import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FloatingPointsWidget extends StatefulWidget {
  const FloatingPointsWidget({Key? key}) : super(key: key);
  @override
  State<FloatingPointsWidget> createState() => _FloatingPointsWidgetState();
}

class _FloatingPointsWidgetState extends State<FloatingPointsWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Offset> _points;
  late final List<double> _velX, _velY, _sizes;
  final Random _random = Random();
  static const int _pointCount = 50;
  final Color _neonBlue = const Color(0xFF00CFFF);

  @override
  void initState() {
    super.initState();
    _initPoints();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  void _initPoints() {
    final width  = ui.window.physicalSize.width / ui.window.devicePixelRatio;
    final height = ui.window.physicalSize.height / ui.window.devicePixelRatio;

    _points = List.generate(
      _pointCount,
      (_) => Offset(_random.nextDouble() * width, _random.nextDouble() * height),
    );
    _velX = List.generate(_pointCount, (_) => (_random.nextDouble() - 0.5) * 2);
    _velY = List.generate(_pointCount, (_) => (_random.nextDouble() - 0.5) * 2);
    _sizes = List.generate(_pointCount, (_) => _random.nextDouble() * 3 + 1);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _FloatingPointsPainter(
        progress: _controller.value,
        points: _points,
        velocitiesX: _velX,
        velocitiesY: _velY,
        sizes: _sizes,
        neonBlue: _neonBlue,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _FloatingPointsPainter extends CustomPainter {
  final double progress;
  final List<Offset> points;
  final List<double> velocitiesX;
  final List<double> velocitiesY;
  final List<double> sizes;
  final Color neonBlue;

  _FloatingPointsPainter({
    required this.progress,
    required this.points,
    required this.velocitiesX,
    required this.velocitiesY,
    required this.sizes,
    required this.neonBlue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintPoint = Paint()..color = neonBlue.withOpacity(0.7);
    final paintGlow  = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..color = neonBlue.withOpacity(0.3);

    for (int i = 0; i < points.length; i++) {
      double x = points[i].dx + velocitiesX[i] * sin(progress * 2 * pi);
      double y = points[i].dy + velocitiesY[i] * cos(progress * 2 * pi);

      if (x < 0) x += size.width;
      if (x > size.width) x -= size.width;
      if (y < 0) y += size.height;
      if (y > size.height) y -= size.height;

      points[i] = Offset(x, y);

      final double pulse = 1 + sin(progress * 4 * pi + i) * 0.2;
      canvas.drawCircle(points[i], sizes[i] * pulse * 1.5, paintGlow);
      canvas.drawCircle(points[i], sizes[i] * pulse, paintPoint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingPointsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
