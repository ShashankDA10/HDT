import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AnimatedOrbitButton extends StatefulWidget {
  final VoidCallback onTap;

  const AnimatedOrbitButton({super.key, required this.onTap});

  @override
  State<AnimatedOrbitButton> createState() => _AnimatedOrbitButtonState();
}

class _AnimatedOrbitButtonState extends State<AnimatedOrbitButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _orbitCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _orbitCtrl]),
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Orbit ring with two travelling dots
                    CustomPaint(
                      size: const Size(88, 88),
                      painter: OrbitRingPainter(
                        progress: _orbitCtrl.value,
                        color: color,
                      ),
                    ),
                    // Pulsing FAB circle
                    Transform.scale(
                      scale: _pulse.value,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.45),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.biotech,
                          color: AppColors.ink,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'MedTwin AI',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OrbitRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const OrbitRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 44.0;

    // Ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Two dots 180° apart travelling around the ring
    final angle = progress * 2 * math.pi;
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < 2; i++) {
      final a = angle + i * math.pi;
      canvas.drawCircle(
        Offset(
          center.dx + radius * math.cos(a),
          center.dy + radius * math.sin(a),
        ),
        4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(OrbitRingPainter old) => old.progress != progress;
}
