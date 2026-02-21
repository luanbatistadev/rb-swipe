import 'dart:math';

import 'package:flutter/material.dart';

class GradientProgressIndicator extends StatefulWidget {
  final double? value;
  final double strokeWidth;
  final double size;

  const GradientProgressIndicator({
    super.key,
    this.value,
    this.strokeWidth = 4.0,
    this.size = 36.0,
  });

  @override
  State<GradientProgressIndicator> createState() =>
      _GradientProgressIndicatorState();
}

class _GradientProgressIndicatorState extends State<GradientProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
      builder: (context, _) {
        if (widget.value != null) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _DeterminatePainter(
              progress: widget.value!,
              rotation: _controller.value * 2 * pi,
              strokeWidth: widget.strokeWidth,
            ),
          );
        }
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _IndeterminatePainter(
            rotation: _controller.value * 2 * pi,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

const _startColor = Color(0xFF6C5CE7);
const _endColor = Color(0xFFA855F7);

class _IndeterminatePainter extends CustomPainter {
  final double rotation;
  final double strokeWidth;

  _IndeterminatePainter({required this.rotation, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const sweepAngle = 1.5 * pi;
    final startAngle = rotation - pi / 2;

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: sweepAngle,
      colors: const [Color(0x006C5CE7), _startColor, _endColor],
      stops: const [0.0, 0.4, 1.0],
      transform: GradientRotation(startAngle),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

    final tipAngle = startAngle + sweepAngle;
    final tipCenter = Offset(
      center.dx + radius * cos(tipAngle),
      center.dy + radius * sin(tipAngle),
    );
    canvas.drawCircle(tipCenter, strokeWidth / 2, Paint()..color = _endColor);
  }

  @override
  bool shouldRepaint(_IndeterminatePainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

class _DeterminatePainter extends CustomPainter {
  final double progress;
  final double rotation;
  final double strokeWidth;

  _DeterminatePainter({
    required this.progress,
    required this.rotation,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = _startColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: sweepAngle,
      colors: const [_startColor, _endColor],
      stops: const [0.0, 1.0],
      transform: const GradientRotation(startAngle),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_DeterminatePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.rotation != rotation;
}
