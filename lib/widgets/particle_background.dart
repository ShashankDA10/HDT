import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class ParticleBackground extends StatefulWidget {
  final int particleCount;
  final Color particleColor;
  final double particleSpeed;

  const ParticleBackground({
    super.key,
    this.particleCount = 50,
    this.particleColor = Colors.white,
    this.particleSpeed = 0.5,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    final random = math.Random();
    _particles = List.generate(
      widget.particleCount,
      (index) => Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        vx: (random.nextDouble() - 0.5) * widget.particleSpeed * 0.01,
        vy: (random.nextDouble() - 0.5) * widget.particleSpeed * 0.01,
        size: random.nextDouble() * 2 + 1,
        opacity: random.nextDouble() * 0.5 + 0.3,
        depth: random.nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(
            particles: _particles,
            progress: _controller.value,
            particleColor: widget.particleColor,
          ),
          child: Container(),
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  double depth;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.depth,
  });

  void update() {
    x += vx;
    y += vy;

    if (x < 0) x = 1;
    if (x > 1) x = 0;
    if (y < 0) y = 1;
    if (y > 1) y = 0;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  final Color particleColor;

  ParticlePainter({
    required this.particles,
    required this.progress,
    required this.particleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundGradient = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.3),
      size.width * 0.9,
      [
        const Color(0xFF0A1020),
        const Color(0xFF0C1428),
        const Color(0xFF0F1A33),
      ],
      [0.0, 0.6, 1.0],
    );

    final backgroundPaint = Paint()..shader = backgroundGradient;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    final particlePaint = Paint()..color = particleColor;

    for (var particle in particles) {
      particle.update();

      final depthScale = 0.5 + particle.depth * 0.5;
      final x = particle.x * size.width;
      final y = particle.y * size.height;

      final effectiveSize = particle.size * depthScale;
      final effectiveOpacity = particle.opacity * (0.5 + particle.depth * 0.5);

      particlePaint.color = particleColor.withOpacity(effectiveOpacity);

      final glowPaint = Paint()
        ..color = particleColor.withOpacity(effectiveOpacity * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(
        Offset(x, y),
        effectiveSize + 2,
        glowPaint,
      );

      canvas.drawCircle(
        Offset(x, y),
        effectiveSize,
        particlePaint,
      );

      for (var other in particles) {
        if (particle == other) continue;

        final dx = (particle.x - other.x) * size.width;
        final dy = (particle.y - other.y) * size.height;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < 150) {
          final connectionOpacity = (1 - distance / 150) * 0.08;
          final connectionPaint = Paint()
            ..color = particleColor.withOpacity(connectionOpacity)
            ..strokeWidth = 0.5;

          canvas.drawLine(
            Offset(particle.x * size.width, particle.y * size.height),
            Offset(other.x * size.width, other.y * size.height),
            connectionPaint,
          );
        }
      }
    }

    final random = math.Random(42);
    final starPaint = Paint()..color = Colors.white;

    for (int i = 0; i < 10; i++) {
      final starX = (random.nextDouble() * size.width);
      final starY = (random.nextDouble() * size.height);
      final twinkle = (math.sin(progress * math.pi * 2 + i) + 1) / 2;

      starPaint.color = Colors.white.withOpacity(0.3 + twinkle * 0.7);

      final starGlow = Paint()
        ..color = Colors.white.withOpacity(twinkle * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      canvas.drawCircle(Offset(starX, starY), 3, starGlow);
      canvas.drawCircle(Offset(starX, starY), 1.5, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return true;
  }
}
