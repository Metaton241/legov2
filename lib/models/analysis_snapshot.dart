import 'detection.dart';
import 'lego_part.dart';

/// Persisted record of a completed analysis run.
class AnalysisSnapshot {
  final String id;
  final DateTime createdAt;
  final String? setLabel; // user-provided set number/name, optional
  final List<LegoPart> inventory;
  final List<Detection> detections;
  final String? pileImagePath; // absolute path inside app docs dir
  final String? inventoryImagePath;

  const AnalysisSnapshot({
    required this.id,
    required this.createdAt,
    this.setLabel,
    required this.inventory,
    required this.detections,
    this.pileImagePath,
    this.inventoryImagePath,
  });

  /// Fingerprint used to match "same LEGO set" across sessions: sorted distinct
  /// `part_id` values joined. Robust to qty differences and ordering.
  String get fingerprint {
    final ids = inventory.map((p) => p.partId).toSet().toList()..sort();
    return ids.join('|');
  }

  int get foundCount {
    int total = 0;
    final counts = <String, int>{};
    for (final d in detections) {
      if (d.confidence < 0.5) continue;
      counts[d.partId] = (counts[d.partId] ?? 0) + 1;
    }
    for (final p in inventory) {
      final f = counts[p.partId] ?? 0;
      total += f > p.qty ? p.qty : f;
    }
    return total;
  }

  int get neededCount => inventory.fold(0, (a, p) => a + p.qty);

  factory AnalysisSnapshot.fromJson(Map<String, dynamic> j) => AnalysisSnapshot(
        id: j['id'].toString(),
        createdAt: DateTime.parse(j['created_at'].toString()),
        setLabel: j['set_label']?.toString(),
        inventory: (j['inventory'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => LegoPart.fromJson(m.cast<String, dynamic>()))
            .toList(),
        detections: (j['detections'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Detection.fromJson(m.cast<String, dynamic>()))
            .toList(),
        pileImagePath: j['pile_image_path']?.toString(),
        inventoryImagePath: j['inventory_image_path']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'set_label': setLabel,
        'inventory': inventory.map((p) => p.toJson()).toList(),
        'detections': detections.map((d) => d.toJson()).toList(),
        'pile_image_path': pileImagePath,
        'inventory_image_path': inventoryImagePath,
      };
}
