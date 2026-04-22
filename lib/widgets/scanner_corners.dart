import 'package:flutter/material.dart';

import '../theme.dart';

/// Wraps a child and draws four L-shaped viewfinder corners around it.
/// When [active] is true the corners gently pulse amber.
class ScannerCorners extends StatefulWidget {
  final Widget child;
  final bool active;
  final double cornerLength;
  final double stroke;
  final double radius;
  final EdgeInsets padding;

  const ScannerCorners({
    super.key,
    required this.child,
    this.active = true,
    this.cornerLength = 24,
    this.stroke = 3,
    this.radius = 16,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ScannerCorners> createState() => _ScannerCornersState();
}

class _ScannerCornersState extends State<ScannerCorners>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (widget.active)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => CustomPaint(
                    painter: _CornerPainter(
                      alpha: 0.55 + 0.45 * _ctrl.value,
                      cornerLength: widget.cornerLength,
                      stroke: widget.stroke,
                      radius: widget.radius,
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CornerPainter(
                    alpha: 0.5,
                    cornerLength: widget.cornerLength,
                    stroke: widget.stroke,
                    radius: widget.radius,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double alpha;
  final double cornerLength;
  final double stroke;
  final double radius;
  final Color color;

  _CornerPainter({
    required this.alpha,
    required this.cornerLength,
    required this.stroke,
    required this.radius,
    this.color = AppColors.amber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final r = radius;
    final L = cornerLength;

    // Top-left
    _corner(canvas, paint,
        start: Offset(0, r + L), mid: Offset(0, r), end: Offset(r + L, 0));
    // Top-right
    _corner(canvas, paint,
        start: Offset(size.width - r - L, 0),
        mid: Offset(size.width, r),
        end: Offset(size.width, r + L));
    // Bottom-right
    _corner(canvas, paint,
        start: Offset(size.width, size.height - r - L),
        mid: Offset(size.width, size.height - r),
        end: Offset(size.width - r - L, size.height));
    // Bottom-left
    _corner(canvas, paint,
        start: Offset(r + L, size.height),
        mid: Offset(0, size.height - r),
        end: Offset(0, size.height - r - L));
  }

  void _corner(Canvas canvas, Paint paint,
      {required Offset start, required Offset mid, required Offset end}) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.alpha != alpha || old.color != color;
}
