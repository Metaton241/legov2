import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme.dart';

/// Animated 2x2 LEGO brick. Studs pulse in a wave, brick gently rotates.
/// Used as the centerpiece of the home screen hero and the loading indicator.
class AnimatedLegoBrick extends StatefulWidget {
  final double size;
  final bool animate;
  const AnimatedLegoBrick({super.key, this.size = 120, this.animate = true});

  @override
  State<AnimatedLegoBrick> createState() => _AnimatedLegoBrickState();
}

class _AnimatedLegoBrickState extends State<AnimatedLegoBrick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedLegoBrick old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final angle = math.sin(_ctrl.value * 2 * math.pi) * (math.pi / 30);
        return Transform.rotate(
          angle: angle,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _BrickPainter(phase: _ctrl.value),
          ),
        );
      },
    );
  }
}

class _BrickPainter extends CustomPainter {
  final double phase; // 0..1
  _BrickPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final w = s * 0.74;
    final h = s * 0.54;
    final top = s * 0.28;
    final left = (size.width - w) / 2;
    final bodyRect = Rect.fromLTWH(left, top, w, h);

    // Drop shadow (bottom).
    final shadow = RRect.fromRectAndRadius(
      bodyRect.shift(const Offset(0, 6)),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(shadow, Paint()..color = Colors.black.withValues(alpha: 0.45));

    // Brick side (darker).
    final sideRect = Rect.fromLTWH(left, top + h * 0.72, w, h * 0.28);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        sideRect,
        bottomLeft: Radius.circular(s * 0.06),
        bottomRight: Radius.circular(s * 0.06),
      ),
      Paint()..color = AppColors.amberDeep,
    );

    // Brick top face.
    final topRect = Rect.fromLTWH(left, top, w, h * 0.78);
    canvas.drawRRect(
      RRect.fromRectAndRadius(topRect, Radius.circular(s * 0.06)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), AppColors.amber],
        ).createShader(topRect),
    );

    // 2x2 studs with wave pulse.
    final studR = s * 0.08;
    final cols = 2, rows = 2;
    final gapX = w * 0.28;
    final gapY = topRect.height * 0.55;
    final startX = left + w * 0.22;
    final startY = top + topRect.height * 0.22;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final idx = r * cols + c;
        final localPhase = (phase + idx * 0.1) % 1.0;
        final pulse = 0.92 + 0.18 * (0.5 + 0.5 * math.sin(localPhase * 2 * math.pi));
        final cx = startX + c * gapX;
        final cy = startY + r * gapY;

        // stud base (darker)
        canvas.drawCircle(
          Offset(cx, cy + studR * 0.25),
          studR * pulse * 1.05,
          Paint()..color = AppColors.amberDeep,
        );
        // stud top
        canvas.drawCircle(
          Offset(cx, cy),
          studR * pulse,
          Paint()
            ..shader = RadialGradient(
              colors: const [Color(0xFFFFE082), AppColors.amber],
              center: const Alignment(-0.3, -0.4),
            ).createShader(Rect.fromCircle(
              center: Offset(cx, cy),
              radius: studR * pulse,
            )),
        );
        // highlight
        canvas.drawCircle(
          Offset(cx - studR * 0.3, cy - studR * 0.35),
          studR * 0.22 * pulse,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BrickPainter old) => old.phase != phase;
}
