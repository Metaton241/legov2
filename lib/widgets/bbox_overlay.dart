import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../theme.dart';

/// Draws detection bounding boxes on top of an image loaded from [imageFile].
/// bbox coordinates are normalized [x, y, w, h] in [0, 1].
class BboxOverlay extends StatefulWidget {
  final File imageFile;
  final List<Detection> detections;
  final void Function(Detection)? onTapDetection;

  const BboxOverlay({
    super.key,
    required this.imageFile,
    required this.detections,
    this.onTapDetection,
  });

  @override
  State<BboxOverlay> createState() => _BboxOverlayState();
}

class _BboxOverlayState extends State<BboxOverlay> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BboxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile.path != widget.imageFile.path) {
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (ctx, c) {
      final fitted = applyBoxFit(
        BoxFit.contain,
        Size(img.width.toDouble(), img.height.toDouble()),
        Size(c.maxWidth, c.maxHeight),
      );
      final dstSize = fitted.destination;
      final dx = (c.maxWidth - dstSize.width) / 2;
      final dy = (c.maxHeight - dstSize.height) / 2;

      return GestureDetector(
        onTapDown: (d) {
          if (widget.onTapDetection == null) return;
          final lx = d.localPosition.dx - dx;
          final ly = d.localPosition.dy - dy;
          for (final det in widget.detections.reversed) {
            final r = Rect.fromLTWH(
              det.x * dstSize.width,
              det.y * dstSize.height,
              det.w * dstSize.width,
              det.h * dstSize.height,
            );
            if (r.contains(Offset(lx, ly))) {
              widget.onTapDetection!(det);
              return;
            }
          }
        },
        child: CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _BboxPainter(
            image: img,
            detections: widget.detections,
            dstOffset: Offset(dx, dy),
            dstSize: dstSize,
          ),
        ),
      );
    });
  }
}

class _BboxPainter extends CustomPainter {
  final ui.Image image;
  final List<Detection> detections;
  final Offset dstOffset;
  final Size dstSize;

  _BboxPainter({
    required this.image,
    required this.detections,
    required this.dstOffset,
    required this.dstSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(
      dstOffset.dx,
      dstOffset.dy,
      dstSize.width,
      dstSize.height,
    );
    canvas.drawImageRect(image, src, dst, Paint());

    for (final d in detections) {
      final color = d.matched ? AppColors.good : AppColors.warn;
      final r = Rect.fromLTWH(
        dstOffset.dx + d.x * dstSize.width,
        dstOffset.dy + d.y * dstSize.height,
        d.w * dstSize.width,
        d.h * dstSize.height,
      );

      final stroke = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawRect(r, stroke);

      final label = _shortLabel(d.name, d.partId);
      final tp = TextPainter(
        text: TextSpan(
          text: ' $label ',
          style: TextStyle(
            color: Colors.black,
            backgroundColor: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, r.topLeft.translate(0, -tp.height));
    }
  }

  /// Short, scannable label for an overlay: prefer the name (truncated),
  /// fall back to the part id.
  static String _shortLabel(String? name, String partId) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '#$partId';
    return n.length <= 20 ? n : '${n.substring(0, 18)}…';
  }

  @override
  bool shouldRepaint(covariant _BboxPainter old) =>
      old.image != image ||
      old.detections != detections ||
      old.dstOffset != dstOffset ||
      old.dstSize != dstSize;
}
