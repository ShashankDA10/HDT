import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;

  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0A1224),
            Color(0xFF0E1830),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                painter: _AuraPainter(),
              ),
            ),
          ),
          Positioned(
            top: -140,
            right: -100,
            child: _GlowOrb(
              size: 280,
              color: AppColors.accentBlue.withOpacity(0.18),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: _GlowOrb(
              size: 320,
              color: AppColors.accent.withOpacity(0.18),
            ),
          ),
          Positioned(
            top: 80,
            left: -160,
            child: _GlowOrb(
              size: 240,
              color: AppColors.accentRose.withOpacity(0.08),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: appBar,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: bottomNavigationBar,
            body: body,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.01),
          ],
        ),
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  const _AuraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    const step = 64.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final hazePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x332DD4BF), Color(0x00000000)],
        radius: 0.8,
      ).createShader(Rect.fromCircle(
        center: Offset(0, size.height * 0.2),
        radius: size.width * 0.9,
      ));

    canvas.drawCircle(Offset(0, size.height * 0.2), size.width * 0.9, hazePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
