import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/detection.dart';

/// Shows the bbox-selected region of [file] cropped to fit the widget.
class CroppedThumb extends StatefulWidget {
  final File file;
  final Detection detection;
  const CroppedThumb({super.key, required this.file, required this.detection});

  @override
  State<CroppedThumb> createState() => _CroppedThumbState();
}

class _CroppedThumbState extends State<CroppedThumb> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) return Container(color: Colors.black26);
    return CustomPaint(
      painter: _CropPainter(image: img, detection: widget.detection),
      size: Size.infinite,
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Detection detection;
  _CropPainter({required this.image, required this.detection});

  @override
  void paint(Canvas canvas, Size size) {
    // Expand bbox by 15% for context around the brick.
    const pad = 0.15;
    final bx = (detection.x - detection.w * pad).clamp(0.0, 1.0);
    final by = (detection.y - detection.h * pad).clamp(0.0, 1.0);
    final bw = (detection.w * (1 + 2 * pad)).clamp(0.0, 1.0 - bx);
    final bh = (detection.h * (1 + 2 * pad)).clamp(0.0, 1.0 - by);

    final src = Rect.fromLTWH(
      bx * image.width,
      by * image.height,
      bw * image.width,
      bh * image.height,
    );

    final srcAspect = src.width / src.height;
    final dstAspect = size.width / size.height;
    Rect dst;
    if (srcAspect > dstAspect) {
      final h = size.width / srcAspect;
      dst = Rect.fromLTWH(0, (size.height - h) / 2, size.width, h);
    } else {
      final w = size.height * srcAspect;
      dst = Rect.fromLTWH((size.width - w) / 2, 0, w, size.height);
    }

    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.image != image || old.detection != detection;
}
