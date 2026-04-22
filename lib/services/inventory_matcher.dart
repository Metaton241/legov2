import '../models/lego_part.dart';

/// Match Brickognize identifications against an [LegoPart] inventory.
///
/// Strategy: ranked candidates → exact part_id → normalized name → token Jaccard
/// (with required size token). Returns the inventory's part_id if matched, else
/// null. Confidence is discounted on weaker match types.
class InventoryMatcher {
  final Set<String> _ids;
  final Map<String, String> _byNormName;
  final Map<String, Set<String>> _tokensById;

  InventoryMatcher(List<LegoPart> inventory)
      : _ids = inventory.map((p) => p.partId).toSet(),
        _byNormName = {
          for (final p in inventory)
            if (p.name.length >= 4) normName(p.name): p.partId,
        },
        _tokensById = {
          for (final p in inventory) p.partId: tokens(p.name),
        };

  /// Returns (matchedPartId, confidenceMultiplier) for the best candidate, or
  /// (null, 0) if nothing matches.
  ///
  /// Iterates [candidates] in ranked order and accepts the first one that hits.
  ({String? id, double mult}) match(
      List<({String id, String name})> candidates) {
    for (final c in candidates) {
      if (_ids.contains(c.id)) {
        return (id: c.id, mult: 1.0);
      }
      final mapped = _byNormName[normName(c.name)];
      if (mapped != null) {
        return (id: mapped, mult: 0.9);
      }
      final fuzzy = _bestTokenMatch(c.name);
      if (fuzzy != null) {
        return (id: fuzzy, mult: 0.75);
      }
    }
    return (id: null, mult: 0);
  }

  String? _bestTokenMatch(String candidateName) {
    final cand = tokens(candidateName);
    if (cand.length < 2) return null;
    String? bestId;
    double bestScore = 0;
    for (final entry in _tokensById.entries) {
      final inv = entry.value;
      if (inv.isEmpty) continue;
      final inter = cand.intersection(inv);
      if (inter.isEmpty) continue;
      final union = cand.union(inv);
      final jacc = inter.length / union.length;
      final hasSize = inter.any((t) => RegExp(r'\d').hasMatch(t));
      if (!hasSize) continue;
      if (jacc >= 0.6 && jacc > bestScore) {
        bestScore = jacc;
        bestId = entry.key;
      }
    }
    return bestId;
  }

  // Public helpers (also used standalone in tap mode).
  static String normName(String name) {
    var n = name.toLowerCase();
    n = n.replaceAll(RegExp(r'[,\-_.()°]+'), ' ');
    n = n.replaceAllMapped(
        RegExp(r'(\d+)\s*x\s*(\d+)'), (m) => '${m[1]}x${m[2]}');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n;
  }

  static Set<String> tokens(String name) {
    final norm = normName(name);
    const stop = {
      'the', 'with', 'and', 'a', 'of', 'in', 'no', 'type', 'style',
    };
    return norm
        .split(' ')
        .where((t) => t.length >= 2 && !stop.contains(t))
        .toSet();
  }
}
