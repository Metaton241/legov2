import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/detection.dart';
import '../models/lego_part.dart';
import 'brickognize_client.dart';
import 'inventory_matcher.dart';

class PipelineProgress {
  final int done;
  final int total;
  final String label;
  const PipelineProgress(this.done, this.total, this.label);
}

class RawIdentification {
  final String partId;
  final String name;
  final double confidence;
  final bool matchedInventory;
  const RawIdentification({
    required this.partId,
    required this.name,
    required this.confidence,
    required this.matchedInventory,
  });
}

class PipelineResult {
  final List<Detection> detections;
  final List<RawIdentification> rawHits;
  final int bboxesFound;
  const PipelineResult({
    required this.detections,
    required this.rawHits,
    required this.bboxesFound,
  });
}

typedef ProgressCallback = void Function(PipelineProgress p);

/// Tile-sweep pipeline using ONLY Brickognize — no kie.ai/Gemini dependency.
///
/// Brickognize identifies one dominant brick per image. To find every brick
/// in a pile, we slice the pile photo into a grid of overlapping tiles and
/// query Brickognize on each tile. Each response carries:
///   - the brick id + name (top item)
///   - a `bounding_box` in tile-pixel coords pointing at where the brick is
///
/// We map those boxes back to global pile coordinates, dedupe overlapping
/// detections (same brick caught by adjacent tiles), and match against the
/// inventory.
class BrickognizePipeline {
  final BrickognizeClient _brk;

  /// Concurrent requests to Brickognize.
  final int concurrency;

  /// Stagger between starting requests in the same worker slot.
  final Duration stagger;

  /// Tile overlap as a fraction of tile width/height. 0.20 = 20% on each side.
  final double overlapFraction;

  /// Max tiles per pile. Falls back to coarser grid for huge images.
  final int maxTiles;

  BrickognizePipeline({
    BrickognizeClient? brickognize,
    this.concurrency = 2,
    this.stagger = const Duration(milliseconds: 200),
    this.overlapFraction = 0.25,
    this.maxTiles = 20,
  }) : _brk = brickognize ?? BrickognizeClient();

  Future<PipelineResult> identify(
    File pileImage,
    List<LegoPart> inventory, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(const PipelineProgress(0, 1, 'Готовлю плитки…'));

    final bytes = await pileImage.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const PipelineResult(
          detections: [], rawHits: [], bboxesFound: 0);
    }

    final tiles = _planTiles(decoded.width, decoded.height);
    if (tiles.isEmpty) {
      return const PipelineResult(
          detections: [], rawHits: [], bboxesFound: 0);
    }

    final matcher = InventoryMatcher(inventory);
    final inventoryNames = {for (final p in inventory) p.partId: p.name};
    final detections = <Detection>[];
    final rawHits = <RawIdentification>[];
    int done = 0;
    final total = tiles.length;
    onProgress?.call(PipelineProgress(0, total, 'Распознаю плитки…'));

    int cursor = 0;
    Future<void> worker(int slot) async {
      while (true) {
        final int? taskIdx = () {
          if (cursor >= tiles.length) return null;
          return cursor++;
        }();
        if (taskIdx == null) break;
        final tile = tiles[taskIdx];
        try {
          final cropBytes = _crop(decoded, tile);
          if (cropBytes != null) {
            await Future.delayed(stagger * slot);
            final items = await _brk.identifyPart(cropBytes,
                filename: 'tile_$taskIdx.jpg');
            if (items.isNotEmpty) {
              final top = items.first;
              final candidates = items
                  .take(5)
                  .map((it) => (id: it.id, name: it.name))
                  .toList();
              final m = matcher.match(candidates);
              rawHits.add(RawIdentification(
                partId: top.id,
                name: top.name,
                confidence: top.score,
                matchedInventory: m.id != null,
              ));
              final box = _mapBox(items, tile,
                  fullW: decoded.width.toDouble(),
                  fullH: decoded.height.toDouble());
              if (m.id != null) {
                detections.add(Detection(
                  partId: m.id!,
                  bbox: box,
                  confidence: top.score * m.mult,
                  name: inventoryNames[m.id!] ?? top.name,
                  matched: true,
                ));
              } else {
                // Either inventory empty or this brick isn't in it. Either
                // way surface it — pile view is more useful with everything.
                detections.add(Detection(
                  partId: top.id,
                  bbox: box,
                  confidence: top.score,
                  name: top.name,
                  matched: false,
                ));
              }
            }
          }
        } catch (_) {
          // Per-tile failures are fine; keep going.
        } finally {
          done++;
          onProgress?.call(PipelineProgress(done, total, 'Распознаю плитки…'));
        }
      }
    }

    await Future.wait([for (var s = 0; s < concurrency; s++) worker(s)]);

    onProgress?.call(PipelineProgress(total, total, 'Готово'));
    return PipelineResult(
      detections: _dedup(detections),
      rawHits: rawHits,
      bboxesFound: rawHits.length,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  List<_Tile> _planTiles(int W, int H) {
    // Choose grid based on aspect ratio. Aim for ~16-20 tiles total — denser
    // grid means smaller tiles, which means Brickognize is more likely to
    // lock onto a single brick per tile (it returns one dominant id).
    int cols, rows;
    final ratio = W / H;
    if (ratio >= 1.4) {
      cols = 5;
      rows = 4;
    } else if (ratio <= 0.7) {
      cols = 4;
      rows = 5;
    } else {
      cols = 4;
      rows = 4;
    }
    while (cols * rows > maxTiles) {
      if (cols >= rows) {
        cols--;
      } else {
        rows--;
      }
    }
    final tileW = W / cols;
    final tileH = H / rows;
    final padX = tileW * overlapFraction;
    final padY = tileH * overlapFraction;
    final out = <_Tile>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x0 = (c * tileW - padX).clamp(0, W.toDouble() - 1);
        final y0 = (r * tileH - padY).clamp(0, H.toDouble() - 1);
        final x1 = ((c + 1) * tileW + padX).clamp(0, W.toDouble());
        final y1 = ((r + 1) * tileH + padY).clamp(0, H.toDouble());
        out.add(_Tile(
          x: x0.round(),
          y: y0.round(),
          w: (x1 - x0).round(),
          h: (y1 - y0).round(),
        ));
      }
    }
    return out;
  }

  Uint8List? _crop(img.Image src, _Tile t) {
    try {
      final region = img.copyCrop(src, x: t.x, y: t.y, width: t.w, height: t.h);
      // Brickognize works fine with 640px max side.
      img.Image out = region;
      final maxSide = region.width > region.height ? region.width : region.height;
      if (maxSide > 640) {
        final scale = 640.0 / maxSide;
        out = img.copyResize(
          region,
          width: (region.width * scale).round(),
          height: (region.height * scale).round(),
          interpolation: img.Interpolation.linear,
        );
      }
      return Uint8List.fromList(img.encodeJpg(out, quality: 85));
    } catch (_) {
      return null;
    }
  }

  /// Map Brickognize's bounding_box (tile-pixel coords reported back in
  /// `bounding_box` field) to global normalized [x, y, w, h]. Falls back to
  /// the entire tile rect if the response shape is unexpected.
  List<double> _mapBox(List<BrickognizeItem> items, _Tile tile,
      {required double fullW, required double fullH}) {
    // BrickognizeClient already strips the bounding_box from the wire format.
    // For now we don't expose it through items — use full tile rect as bbox.
    final x = tile.x / fullW;
    final y = tile.y / fullH;
    final w = tile.w / fullW;
    final h = tile.h / fullH;
    return [
      x.clamp(0.0, 1.0),
      y.clamp(0.0, 1.0),
      w.clamp(0.0, 1.0),
      h.clamp(0.0, 1.0),
    ];
  }

  List<Detection> _dedup(List<Detection> dets) {
    if (dets.length < 2) return dets;
    // Group by part_id, NMS within each group, then return concatenation.
    final byId = <String, List<Detection>>{};
    for (final d in dets) {
      byId.putIfAbsent(d.partId, () => []).add(d);
    }
    final out = <Detection>[];
    for (final group in byId.values) {
      group.sort((a, b) => b.confidence.compareTo(a.confidence));
      final kept = <Detection>[];
      for (final d in group) {
        final clashes = kept.any((k) => _iou(d, k) > 0.4);
        if (!clashes) kept.add(d);
      }
      out.addAll(kept);
    }
    return out;
  }

  double _iou(Detection a, Detection b) {
    final ax2 = a.x + a.w, ay2 = a.y + a.h;
    final bx2 = b.x + b.w, by2 = b.y + b.h;
    final ix1 = a.x > b.x ? a.x : b.x;
    final iy1 = a.y > b.y ? a.y : b.y;
    final ix2 = ax2 < bx2 ? ax2 : bx2;
    final iy2 = ay2 < by2 ? ay2 : by2;
    final iw = ix2 - ix1;
    final ih = iy2 - iy1;
    if (iw <= 0 || ih <= 0) return 0.0;
    final inter = iw * ih;
    final union = a.w * a.h + b.w * b.h - inter;
    return union <= 0 ? 0.0 : inter / union;
  }
}

class _Tile {
  final int x, y, w, h;
  const _Tile({required this.x, required this.y, required this.w, required this.h});
}
