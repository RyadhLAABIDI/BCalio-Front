import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services; // ← rootBundle

class CelestialOrbitsBackground extends StatefulWidget {
  const CelestialOrbitsBackground({
    super.key,
    this.overlayMode = false, // ← NEW
  });

  /// When true, paints with additive blend (stars/halo “shine through” dark surfaces).
  final bool overlayMode; // ← NEW

  @override
  State<CelestialOrbitsBackground> createState() => _CelestialOrbitsBackgroundState();
}

class _CelestialOrbitsBackgroundState extends State<CelestialOrbitsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Star> _stars;
  final _rng = math.Random();

  ui.Image? _planetImg; // ← texture optionnelle

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..addListener(() => setState(() {}))
      ..repeat();

    // starfield fixe (léger flicker)
    _stars = List.generate(140, (_) => _Star(
          x: 0, y: 0,
          r: _rnd(0.6, 1.9),
          flicker: _rnd(0.25, .85),
          phase: _rnd(0, 6.28318),
        ));

    _tryLoadPlanetTexture(); // charge une texture si dispo
  }

  double _rnd(double a, double b) => a + _rng.nextDouble() * (b - a);

  Future<void> _tryLoadPlanetTexture() async {
    const candidates = [
      'assets/jupiter.jpg',
      'assets/planets/jupiter.jpg',
      'assets/planets/planet.jpg',
      'assets/planets/jupiter.png',
      'assets/planet.jpg',
    ];
    for (final path in candidates) {
      try {
        final data = await services.rootBundle.load(path);
        final img = await decodeImageFromList(data.buffer.asUint8List());
        if (!mounted) return;
        setState(() => _planetImg = img);
        break;
      } catch (_) {/* next */}
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final size = Size(c.maxWidth, c.maxHeight);

      // place les étoiles une seule fois après avoir la taille
      if (_stars.any((s) => s.x == 0 && s.y == 0)) {
        for (final s in _stars) {
          s.x = _rng.nextDouble() * size.width;
          s.y = _rng.nextDouble() * size.height;
        }
      }

      return RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: _CelestialPainter(
            t: _ctrl.value,
            stars: _stars,
            planet: _planetImg,     // ← passe la texture (peut être null)
            overlayMode: widget.overlayMode, // ← NEW
          ),
        ),
      );
    });
  }
}

class _Star {
  double x, y, r, flicker, phase;
  _Star({required this.x, required this.y, required this.r, required this.flicker, required this.phase});
}

class _CelestialPainter extends CustomPainter {
  final double t;
  final List<_Star> stars;
  final ui.Image? planet;
  final bool overlayMode;                           // ← NEW

  _CelestialPainter({
    required this.t,
    required this.stars,
    this.planet,
    this.overlayMode = false,                       // ← NEW
  });

  @override
  void paint(Canvas canvas, Size size) {
    // In overlayMode, draw on a layer with BlendMode.plus so it “adds light” over UI.
    if (overlayMode) {
      final layerPaint = Paint()..blendMode = BlendMode.plus;
      canvas.saveLayer(Offset.zero & size, layerPaint);
      _paintScene(canvas, size, overlay: true);
      canvas.restore();
    } else {
      _paintScene(canvas, size, overlay: false);
    }
  }

  void _paintScene(Canvas canvas, Size size, {required bool overlay}) {
    final cx = size.width / 2, cy = size.height / 2;

    if (!overlay) {
      _bgGradient(canvas, size);
      _drawNebulaVignette(canvas, size);
    } else {
      // overlay: peindre juste une nébuleuse légère + halos (pas de fond opaque)
      _drawNebulaVignette(canvas, size, overlay: true);
    }

    // planète
    final planetRadius = size.shortestSide * .36;
    _corePlanet(canvas, size, planetRadius, overlay: overlay);

    // ====== ORBITES + SATELLITES ======
    // ⚠️ Modif : on NE TRACE PLUS les cercles d’orbite (mais on garde les satellites).
    final orbits = [
      _Orbit(a: size.shortestSide * 0.30, b: size.shortestSide * 0.22, speed: 0.12, hue: 186),
      _Orbit(a: size.shortestSide * 0.40, b: size.shortestSide * 0.30, speed: -0.09, hue: 188),
      _Orbit(a: size.shortestSide * 0.52, b: size.shortestSide * 0.38, speed: 0.07, hue: 190),
    ];
    for (final o in orbits) {
      // _orbit(canvas, cx, cy, o, size, overlay: overlay); // ← supprimé
      _satellites(canvas, cx, cy, o, size, overlay: overlay); // ← on garde
    }

    // étoiles
    _drawStars(canvas, size, overlay: overlay);

    // branding
    if (!overlay) {
      _brandCenter(canvas, size, planetRadius);
    } else {
      // overlay: un léger rehaussement vertical (spec) pour “respirer”
      _brandSpecOverlay(canvas, size);
    }
  }

  // ---------- BACKGROUND ----------
  void _bgGradient(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        [const Color(0xFF05080C), const Color(0xFF070B11), const Color(0xFF05090F)],
        [0, .6, 1],
      );
    canvas.drawRect(rect, p);
  }

  void _drawNebulaVignette(Canvas canvas, Size size, {bool overlay = false}) {
    final nebula = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.48),
        size.longestSide * 0.9,
        [
          const Color(0xFF00D1D4).withOpacity(overlay ? .12 : .20),
          const Color(0xFF00D1D4).withOpacity(overlay ? .03 : .06),
          Colors.transparent,
        ],
        [0.0, .28, 1.0],
      );
    canvas.drawRect(Offset.zero & size, nebula);

    if (!overlay) {
      final vig = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .5, size.height * .5),
          size.longestSide * 0.85,
          [Colors.transparent, Colors.black.withOpacity(.42)],
          [.68, 1],
        );
      canvas.drawRect(Offset.zero & size, vig);
    }
  }

  // ---------- PLANÈTE ----------
  void _corePlanet(Canvas canvas, Size size, double r, {bool overlay = false}) {
    final c = Offset(size.width / 2, size.height / 2);

    // halo atmosphérique externe
    final atm = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36)
      ..color = const Color(0xFF00CFFF).withOpacity(overlay ? 0.18 : 0.22);
    canvas.drawCircle(c, r * 1.45, atm);

    if (overlay) {
      // En overlay: ne peins PAS le cœur solide; juste un reflets doux
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = const Color(0xFF9FE9FF).withOpacity(.18);
      canvas.drawCircle(c, r, rim);
      return;
    }

    if (planet != null) {
      final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
      canvas.save();
      canvas.clipPath(circle);

      final imgW = planet!.width.toDouble();
      final imgH = planet!.height.toDouble();
      final scale = (2 * r) / math.min(imgW, imgH);
      final shift = (t * imgW * 0.25) % imgW;

      final m = Float64List.fromList([
        scale, 0,     0, 0,
        0,     scale, 0, 0,
        0,     0,     1, 0,
        c.dx - r - shift * scale, c.dy - r, 0, 1,
      ]);

      final shader = ui.ImageShader(
        planet!, TileMode.repeated, TileMode.clamp, m,
      );

      final tex = Paint()..shader = shader;
      canvas.drawRect(Rect.fromCircle(center: c, radius: r), tex);

      // terminator
      final dir = Offset(1, -0.18).direction;
      final lightEdge = Offset(c.dx + r * math.cos(dir), c.dy + r * math.sin(dir));
      final darkEdge  = Offset(c.dx - r * math.cos(dir), c.dy - r * math.sin(dir));
      final terminator = Paint()
        ..shader = ui.Gradient.linear(
          darkEdge, lightEdge,
          [Colors.black.withOpacity(.55), Colors.transparent, Colors.white.withOpacity(.07)],
          [0.0, 0.58, 1.0],
        );
      canvas.drawCircle(c, r, terminator);

      canvas.restore();
    } else {
      final glow = Paint()
        ..shader = ui.Gradient.radial(
          c, r * 1.55,
          [const Color(0xFF00D1D4).withOpacity(.36), const Color(0xFF00D1D4).withOpacity(.08), Colors.transparent],
          [0, .42, 1],
        );
      canvas.drawCircle(c, r * 1.5, glow);

      final core = Paint()
        ..shader = ui.Gradient.radial(
          c, r * 0.98,
          [const Color(0xFF0C1418), const Color(0xFF070D12)],
          [0, 1],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(c, r, core);
    }
  }

  // ---------- ORBITES ----------
  void _orbit(Canvas canvas, double cx, double cy, _Orbit o, Size size, {bool overlay = false}) {
    // (fonction gardée pour compat, mais non appelée)
    final path = Path();
    const points = 220;
    for (int i = 0; i <= points; i++) {
      final a = (i / points) * math.pi * 2;
      final wobble = math.sin((t * 2 + a) * 0.7) * 2.0;
      final x = cx + (o.a + wobble) * math.cos(a);
      final y = cy + (o.b - wobble) * math.sin(a);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }

    final col = HSLColor.fromAHSL(1, o.hue.toDouble(), 0.75, 0.55).toColor();
    final baseAlpha = overlay ? .10 : .20;

    final p1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = col.withOpacity(baseAlpha);
    canvas.drawPath(path, p1);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = col.withOpacity(baseAlpha * .5);
    canvas.drawPath(path, glow);
  }

  void _satellites(Canvas canvas, double cx, double cy, _Orbit o, Size size, {bool overlay = false}) {
    for (int i = 0; i < 3; i++) {
      final phase = (i / 3) * math.pi * 2;
      final a = (t * o.speed * math.pi * 2) + phase;
      final wobble = math.cos((t * 2 + phase) * .8) * 2.0;

      final x = cx + (o.a + wobble) * math.cos(a);
      final y = cy + (o.b - wobble) * math.sin(a);

      final col = HSLColor.fromAHSL(1, o.hue.toDouble(), 0.85, 0.62).toColor();
      final blur = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = col.withOpacity(overlay ? .35 : .55);
      final dot = Paint()..color = col.withOpacity(overlay ? .70 : .95);

      canvas.drawCircle(Offset(x, y), 4.6, blur);
      canvas.drawCircle(Offset(x, y), 2.2, dot);
    }
  }

  // ---------- STARS ----------
  void _drawStars(Canvas canvas, Size size, {bool overlay = false}) {
    final p = Paint()..color = Colors.white.withOpacity(.65);
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..color = const Color(0xFFBFEFFF).withOpacity(.35);

    for (final s in stars) {
      final op = (0.6 + 0.4 * math.sin(t * 6.28318 + s.phase)) * s.flicker;
      p.color    = Colors.white.withOpacity(op * (overlay ? 0.35 : 0.55));
      glow.color = const Color(0xFFBFEFFF).withOpacity(op * (overlay ? 0.22 : 0.35));

      final o = Offset(s.x, s.y);
      canvas.drawCircle(o, s.r * 2.2, glow);
      canvas.drawCircle(o, s.r, p);
    }
  }

  // ---------- BCallio CENTRÉ ----------
  void _brandCenter(Canvas canvas, Size size, double planetR) {
    final c = Offset(size.width / 2, size.height / 2);
    const text = 'BCallio';

    final fontSize = (planetR * 0.55).clamp(32.0, 86.0);
    final neon = const Color(0xFF00CFFF);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: Colors.white.withOpacity(.96),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final off = c - Offset(tp.width / 2, tp.height / 2);
    final textRect = Rect.fromLTWH(off.dx, off.dy, tp.width, tp.height);

    final outerGlow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color = neon.withOpacity(.35);
    final innerGlow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = neon.withOpacity(.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(textRect.inflate(14), const Radius.circular(12)),
      outerGlow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(textRect.inflate(6), const Radius.circular(10)),
      innerGlow,
    );

    // ====== Couleurs demandées (même animation & brillance conservées) ======
    final coolTP = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: const Color(0xFF327E88).withOpacity(.90), // froid
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final warmTP = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: const Color(0xFFC46535).withOpacity(.10), // chaud
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final split = 0.6 + 0.4 * math.sin(t * math.pi * 2);
    coolTP.paint(canvas, off + Offset(1.2 * split, 0.6 * split));
    warmTP.paint(canvas, off - Offset(0.8 * split, 0.4 * split));

    final layer = Rect.fromLTWH(off.dx - 18, off.dy - 18, tp.width + 36, tp.height + 36);
    canvas.saveLayer(layer, Paint());
    tp.paint(canvas, off);

    final sweepW = tp.width * 1.2;
    final x = off.dx + (tp.width + sweepW) * (t % 1.0) - sweepW * 0.6;
    final shimmer = Paint()
      ..blendMode = BlendMode.srcIn
      ..shader = ui.Gradient.linear(
        Offset(x, off.dy),
        Offset(x + sweepW, off.dy + tp.height),
        [
          Colors.transparent,
          Colors.white.withOpacity(.85),
          Colors.transparent,
        ],
        [.32, .5, .68],
      );
    canvas.drawRect(layer, shimmer);
    canvas.restore();

    final spec = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..shader = ui.Gradient.linear(
        Offset(off.dx, off.dy + tp.height * .5),
        Offset(off.dx + tp.width, off.dy + tp.height * .5),
        [Colors.transparent, Colors.white.withOpacity(.35), Colors.transparent],
        [0.2, 0.5, 0.8],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(off.dx, off.dy + tp.height * .45, tp.width, tp.height * .10),
        const Radius.circular(6),
      ),
      spec,
    );
  }

  // léger rehaut en overlay pour “continuité”
  void _brandSpecOverlay(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final w = size.shortestSide * 0.42;
    final h = w * 0.18;
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    final p = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..shader = ui.Gradient.linear(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        [Colors.transparent, const Color(0xFFCCF6FF).withOpacity(.18), Colors.transparent],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), p);
  }

  @override
  bool shouldRepaint(covariant _CelestialPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.stars != stars ||
      oldDelegate.planet != planet ||
      oldDelegate.overlayMode != overlayMode;
}

class _Orbit {
  final double a, b; // demi-axes ellipse
  final double speed;
  final int hue;
  _Orbit({required this.a, required this.b, required this.speed, required this.hue});
}
