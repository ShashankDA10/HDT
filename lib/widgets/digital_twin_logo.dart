import 'package:flutter/material.dart';
import 'dart:math' as math;

class DigitalTwinLogo extends StatefulWidget {
  final double size;
  final bool animated;
  final Color? color;

  const DigitalTwinLogo({
    super.key,
    this.size = 120,
    this.animated = true,
    this.color,
  });

  @override
  State<DigitalTwinLogo> createState() => _DigitalTwinLogoState();
}

class _DigitalTwinLogoState extends State<DigitalTwinLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat();
      
      _waveAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));
    }
  }

  @override
  void dispose() {
    if (widget.animated) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoColor = widget.color ?? Colors.white;
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.animated
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: MinimalistLogoPainter(
                    color: logoColor,
                    waveProgress: _waveAnimation.value,
                  ),
                );
              },
            )
          : CustomPaint(
              painter: MinimalistLogoPainter(
                color: logoColor,
                waveProgress: 0.0,
              ),
            ),
    );
  }
}

class MinimalistLogoPainter extends CustomPainter {
  final Color color;
  final double waveProgress;

  MinimalistLogoPainter({
    required this.color,
    this.waveProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final padding = size.width * 0.15;
    final rectWidth = size.width * 0.12;
    final rectHeight = size.height * 0.08;
    final spacing = size.height * 0.12;

    // Draw central undulating waveform
    final wavePath = Path();
    final waveStartX = padding + rectWidth + 10;
    final waveEndX = size.width - padding - rectWidth - 10;
    final waveAmplitude = size.height * 0.15;
    final peakX = size.width * 0.4; // Peak slightly left of center
    
    wavePath.moveTo(waveStartX, centerY + waveAmplitude * 0.3);
    
    // Create smooth curve with peak
    final controlPoint1X = waveStartX + (peakX - waveStartX) * 0.5;
    final controlPoint1Y = centerY - waveAmplitude;
    final controlPoint2X = peakX;
    final controlPoint2Y = centerY - waveAmplitude;
    
    wavePath.cubicTo(
      controlPoint1X,
      controlPoint1Y,
      controlPoint2X,
      controlPoint2Y,
      peakX,
      centerY - waveAmplitude,
    );
    
    // Continue down to the right
    final controlPoint3X = peakX + (waveEndX - peakX) * 0.3;
    final controlPoint3Y = centerY + waveAmplitude * 0.2;
    
    wavePath.cubicTo(
      peakX + (waveEndX - peakX) * 0.2,
      centerY,
      controlPoint3X,
      controlPoint3Y,
      waveEndX,
      centerY + waveAmplitude * 0.4,
    );
    
    canvas.drawPath(wavePath, paint);

    // Draw 3 rectangles on the left (stacked vertically)
    final leftX = padding;
    final topRectY = centerY - spacing - rectHeight / 2;
    final middleRectY = centerY - rectHeight / 2;
    final bottomRectY = centerY + spacing - rectHeight / 2;

    _drawRectangle(canvas, paint, leftX, topRectY, rectWidth, rectHeight);
    _drawRectangle(canvas, paint, leftX, middleRectY, rectWidth, rectHeight);
    _drawRectangle(canvas, paint, leftX, bottomRectY, rectWidth, rectHeight);

    // Draw 2 rectangles on the right (stacked vertically)
    final rightX = size.width - padding - rectWidth;
    final rightTopRectY = centerY - spacing / 2 - rectHeight / 2;
    final rightBottomRectY = centerY + spacing / 2 - rectHeight / 2;

    _drawRectangle(canvas, paint, rightX, rightTopRectY, rectWidth, rectHeight);
    _drawRectangle(canvas, paint, rightX, rightBottomRectY, rectWidth, rectHeight);

    // Draw smaller dashed square below the right rectangles
    final smallSquareSize = rectWidth * 0.7;
    final smallSquareX = rightX + (rectWidth - smallSquareSize) / 2;
    final smallSquareY = rightBottomRectY + rectHeight + spacing * 0.6;

    // Draw dashed border for the small square
    final dashPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const dashLength = 3.0;
    const dashSpace = 3.0;

    // Draw dashed rectangle
    _drawDashedRect(
      canvas,
      dashPaint,
      smallSquareX,
      smallSquareY,
      smallSquareSize,
      smallSquareSize,
      dashLength,
      dashSpace,
    );

    // Draw corner indicators (small squares at corners and midpoints)
    const indicatorSize = 3.0;
    final indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Top-left corner
    canvas.drawRect(
      Rect.fromLTWH(smallSquareX, smallSquareY, indicatorSize, indicatorSize),
      indicatorPaint,
    );
    // Top-right corner
    canvas.drawRect(
      Rect.fromLTWH(
        smallSquareX + smallSquareSize - indicatorSize,
        smallSquareY,
        indicatorSize,
        indicatorSize,
      ),
      indicatorPaint,
    );
    // Bottom-left corner
    canvas.drawRect(
      Rect.fromLTWH(
        smallSquareX,
        smallSquareY + smallSquareSize - indicatorSize,
        indicatorSize,
        indicatorSize,
      ),
      indicatorPaint,
    );
    // Bottom-right corner
    canvas.drawRect(
      Rect.fromLTWH(
        smallSquareX + smallSquareSize - indicatorSize,
        smallSquareY + smallSquareSize - indicatorSize,
        indicatorSize,
        indicatorSize,
      ),
      indicatorPaint,
    );
    // Top midpoint
    canvas.drawRect(
      Rect.fromLTWH(
        smallSquareX + smallSquareSize / 2 - indicatorSize / 2,
        smallSquareY,
        indicatorSize,
        indicatorSize,
      ),
      indicatorPaint,
    );
    // Bottom midpoint
    canvas.drawRect(
      Rect.fromLTWH(
        smallSquareX + smallSquareSize / 2 - indicatorSize / 2,
        smallSquareY + smallSquareSize - indicatorSize,
        indicatorSize,
        indicatorSize,
      ),
      indicatorPaint,
    );
    // Left midpoint
    canvas.drawRect(
      Rect.fromLTWH(
        smallSquareX,
        smallSquareY + smallSquareSize / 2 - indicatorSize / 2,
        indicatorSize,
        indicatorSize,
      ),
      indicatorPaint,
    );
    // Right midpoint
    canvas.drawRect(
      Rect.fromLTWH(
        smallSquareX + smallSquareSize - indicatorSize,
        smallSquareY + smallSquareSize / 2 - indicatorSize / 2,
        indicatorSize,
        indicatorSize,
      ),
      indicatorPaint,
    );

    // Draw horizontal scrollbar at the bottom
    final scrollbarY = size.height - 8;
    final scrollbarWidth = size.width * 0.6;
    final scrollbarX = (size.width - scrollbarWidth) / 2;
    const scrollbarHeight = 4.0;

    final scrollbarPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(scrollbarX, scrollbarY, scrollbarWidth, scrollbarHeight),
        const Radius.circular(2),
      ),
      scrollbarPaint,
    );
  }

  void _drawRectangle(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double width,
    double height,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(x, y, width, height),
      paint,
    );
  }

  void _drawDashedRect(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double width,
    double height,
    double dashLength,
    double dashSpace,
  ) {
    // Top edge
    _drawDashedLine(canvas, paint, Offset(x, y), Offset(x + width, y), dashLength, dashSpace);
    // Right edge
    _drawDashedLine(canvas, paint, Offset(x + width, y), Offset(x + width, y + height), dashLength, dashSpace);
    // Bottom edge
    _drawDashedLine(canvas, paint, Offset(x + width, y + height), Offset(x, y + height), dashLength, dashSpace);
    // Left edge
    _drawDashedLine(canvas, paint, Offset(x, y + height), Offset(x, y), dashLength, dashSpace);
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashLength,
    double dashSpace,
  ) {
    final path = Path();
    final distance = (end - start).distance;
    final direction = (end - start) / distance;
    double currentDistance = 0.0;
    bool draw = true;

    while (currentDistance < distance) {
      final currentPoint = start + direction * currentDistance;
      final nextDistance = currentDistance + (draw ? dashLength : dashSpace);
      final nextPoint = start + direction * math.min(nextDistance, distance);

      if (draw) {
        path.moveTo(currentPoint.dx, currentPoint.dy);
        path.lineTo(nextPoint.dx, nextPoint.dy);
      }

      currentDistance = nextDistance;
      draw = !draw;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MinimalistLogoPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.waveProgress != waveProgress;
  }
}
