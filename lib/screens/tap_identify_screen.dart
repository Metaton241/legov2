import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../models/detection.dart';
import '../services/brickognize_client.dart';
import '../state/analysis_provider.dart';
import '../theme.dart';
import 'result_screen.dart';

/// Interactive identification — user taps on each brick in the pile photo
/// and the app crops around the tap and sends the crop to Brickognize.
/// Each accepted hit becomes a [Detection] that's shown as a pin on the image.
class TapIdentifyScreen extends ConsumerStatefulWidget {
  final File pileImage;
  const TapIdentifyScreen({super.key, required this.pileImage});

  @override
  ConsumerState<TapIdentifyScreen> createState() => _TapIdentifyScreenState();
}

class _TapIdentifyScreenState extends ConsumerState<TapIdentifyScreen> {
  ui.Image? _uiImage;
  img.Image? _imgImage;
  final List<_Pin> _pins = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.pileImage.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final decoded = img.decodeImage(bytes);
    if (!mounted) return;
    setState(() {
      _uiImage = frame.image;
      _imgImage = decoded;
    });
  }

  Future<void> _handleTap(Offset local, Size widgetSize) async {
    final img0 = _imgImage;
    final ui0 = _uiImage;
    if (img0 == null || ui0 == null) return;

    // Map tap from widget-local -> image-pixel coordinates.
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(ui0.width.toDouble(), ui0.height.toDouble()),
      widgetSize,
    );
    final dst = fitted.destination;
    final dx = (widgetSize.width - dst.width) / 2;
    final dy = (widgetSize.height - dst.height) / 2;
    final lx = local.dx - dx;
    final ly = local.dy - dy;
    if (lx < 0 || ly < 0 || lx > dst.width || ly > dst.height) return;
    final px = (lx / dst.width) * img0.width;
    final py = (ly / dst.height) * img0.height;

    // Crop a square window around the tap. Window size scales with image.
    final window = (img0.width < img0.height ? img0.width : img0.height) ~/ 5;
    final cx = (px - window / 2).round().clamp(0, img0.width - 1);
    final cy = (py - window / 2).round().clamp(0, img0.height - 1);
    final cw = window.clamp(1, img0.width - cx);
    final ch = window.clamp(1, img0.height - cy);

    final pin = _Pin(
      id: DateTime.now().millisecondsSinceEpoch,
      normX: px / img0.width,
      normY: py / img0.height,
      status: _PinStatus.loading,
    );
    setState(() {
      _pins.add(pin);
      _loading = true;
    });

    try {
      final crop = img.copyCrop(img0, x: cx, y: cy, width: cw, height: ch);
      // Downscale.
      img.Image out = crop;
      final maxSide = crop.width > crop.height ? crop.width : crop.height;
      if (maxSide > 640) {
        final scale = 640.0 / maxSide;
        out = img.copyResize(
          crop,
          width: (crop.width * scale).round(),
          height: (crop.height * scale).round(),
          interpolation: img.Interpolation.linear,
        );
      }
      final bytes = Uint8List.fromList(img.encodeJpg(out, quality: 85));
      final client = ref.read(brickognizeClientProvider);
      final items = await client.identifyPart(bytes, filename: 'tap_${pin.id}.jpg');

      final inventory = ref.read(analysisProvider).inventory;
      final inventoryIds = inventory.map((p) => p.partId).toSet();
      final inventoryByNorm = <String, String>{
        for (final p in inventory)
          if (p.name.length > 3) _norm(p.name): p.partId,
      };

      // Walk top-5 candidates; first match wins (id → normalized name).
      String? matchedId;
      BrickognizeItem? picked;
      for (final it in items.take(5)) {
        if (inventoryIds.contains(it.id)) {
          matchedId = it.id;
          picked = it;
          break;
        }
        final mapped = inventoryByNorm[_norm(it.name)];
        if (mapped != null) {
          matchedId = mapped;
          picked = it;
          break;
        }
      }

      setState(() {
        final idx = _pins.indexWhere((p) => p.id == pin.id);
        if (idx < 0) return;
        if (items.isEmpty) {
          _pins[idx] = pin.copyWith(status: _PinStatus.miss, label: '?');
        } else {
          final top = items.first;
          final inInventory = matchedId != null;
          _pins[idx] = pin.copyWith(
            status: inInventory ? _PinStatus.hit : _PinStatus.other,
            // Show readable name instead of bare part_id.
            label: _shortName(picked?.name ?? top.name),
            partId: matchedId ?? top.id,
            name: picked?.name ?? top.name,
            confidence: picked?.score ?? top.score,
            cropBox: [cx / img0.width, cy / img0.height, cw / img0.width, ch / img0.height],
          );
        }
      });
    } catch (e) {
      setState(() {
        final idx = _pins.indexWhere((p) => p.id == pin.id);
        if (idx >= 0) {
          _pins[idx] = pin.copyWith(status: _PinStatus.error, label: '!');
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _norm(String s) {
    var n = s.toLowerCase();
    n = n.replaceAll(RegExp(r'[,\-_.()°]+'), ' ');
    n = n.replaceAllMapped(
        RegExp(r'(\d+)\s*x\s*(\d+)'), (m) => '${m[1]}x${m[2]}');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n;
  }

  /// Compact human label for a pin — drops leading "Part," / "Plate," etc and
  /// truncates to 18 chars max so multiple pins don't collide on screen.
  static String _shortName(String s) {
    final cleaned = s.replaceAll(RegExp(r',\s*'), ' ').trim();
    return cleaned.length <= 18 ? cleaned : '${cleaned.substring(0, 16)}…';
  }

  void _finish() {
    final detections = _pins
        .where((p) =>
            (p.status == _PinStatus.hit || p.status == _PinStatus.other) &&
            p.cropBox != null &&
            (p.partId?.isNotEmpty ?? false))
        .map((p) => Detection(
              partId: p.partId!,
              bbox: p.cropBox!,
              confidence: p.confidence ?? 0.7,
              name: p.name,
              matched: p.status == _PinStatus.hit,
            ))
        .toList();

    final ctrl = ref.read(analysisProvider.notifier);
    ctrl.commitDetections(detections, pileImage: widget.pileImage);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => const ResultScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ui0 = _uiImage;
    final hits = _pins.where((p) => p.status == _PinStatus.hit).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тап-режим'),
        actions: [
          TextButton.icon(
            onPressed: _pins.isEmpty ? null : _finish,
            icon: const Icon(Icons.check_rounded, color: AppColors.amber),
            label: const Text('Завершить',
                style: TextStyle(color: AppColors.amber)),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (ui0 == null)
            const Center(child: CircularProgressIndicator())
          else
            Positioned.fill(
              child: LayoutBuilder(builder: (ctx, c) {
                return GestureDetector(
                  onTapDown: _loading
                      ? null
                      : (d) => _handleTap(d.localPosition,
                          Size(c.maxWidth, c.maxHeight)),
                  child: CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _PileWithPinsPainter(
                      image: ui0,
                      pins: _pins,
                    ),
                  ),
                );
              }),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      color: AppColors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loading
                          ? 'Распознаю…'
                          : 'Тапни по каждой детали в куче. Найдено из списка: $hits',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PinStatus { loading, hit, other, miss, error }

class _Pin {
  final int id;
  final double normX;
  final double normY;
  final _PinStatus status;
  final String label;     // short label drawn on canvas (truncated name)
  final String? partId;   // matched inventory id OR raw Brickognize id
  final String? name;     // full descriptive name
  final double? confidence;
  final List<double>? cropBox; // normalized xywh

  _Pin({
    required this.id,
    required this.normX,
    required this.normY,
    required this.status,
    this.label = '',
    this.partId,
    this.name,
    this.confidence,
    this.cropBox,
  });

  _Pin copyWith({
    _PinStatus? status,
    String? label,
    String? partId,
    String? name,
    double? confidence,
    List<double>? cropBox,
  }) =>
      _Pin(
        id: id,
        normX: normX,
        normY: normY,
        status: status ?? this.status,
        label: label ?? this.label,
        partId: partId ?? this.partId,
        name: name ?? this.name,
        confidence: confidence ?? this.confidence,
        cropBox: cropBox ?? this.cropBox,
      );
}

class _PileWithPinsPainter extends CustomPainter {
  final ui.Image image;
  final List<_Pin> pins;
  _PileWithPinsPainter({required this.image, required this.pins});

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(image.width.toDouble(), image.height.toDouble()),
      size,
    );
    final dst = fitted.destination;
    final dx = (size.width - dst.width) / 2;
    final dy = (size.height - dst.height) / 2;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(dx, dy, dst.width, dst.height),
      Paint(),
    );

    for (final p in pins) {
      final px = dx + p.normX * dst.width;
      final py = dy + p.normY * dst.height;
      final color = switch (p.status) {
        _PinStatus.hit => AppColors.good,
        _PinStatus.other => AppColors.warn,
        _PinStatus.miss => AppColors.bad,
        _PinStatus.error => AppColors.bad,
        _PinStatus.loading => AppColors.amber,
      };
      // Outer ring.
      canvas.drawCircle(Offset(px, py), 18,
          Paint()..color = color.withValues(alpha: 0.25));
      // Inner dot.
      canvas.drawCircle(Offset(px, py), 7, Paint()..color = color);
      // Label — prefer name (set by _shortName) else fall back to label as id.
      if (p.label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: ' ${p.label} ',
            style: TextStyle(
              color: Colors.black,
              backgroundColor: color.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(px + 10, py - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PileWithPinsPainter old) =>
      old.image != image || old.pins != pins;
}
