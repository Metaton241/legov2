import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

/// Offline lookup table that maps LEGO Element IDs (7-digit catalogue numbers
/// printed in instructions) to BrickLink-style design part numbers that
/// Brickognize returns.
///
/// Source: Rebrickable public dataset `elements.csv`, stripped to just the two
/// columns we need (`element_id,part_num`) and gzipped. Bundled in assets so
/// the feature works fully offline, no API key required.
class ElementLookup {
  static final ElementLookup _instance = ElementLookup._();
  factory ElementLookup() => _instance;
  ElementLookup._();

  Map<String, String>? _map;
  Future<Map<String, String>>? _loading;

  /// Returns the full element→part map. Cached after first call. The first
  /// call takes ~200-400ms on mid-range phones (parsing 110k rows).
  Future<Map<String, String>> load() {
    if (_map != null) return Future.value(_map);
    return _loading ??= _doLoad();
  }

  Future<Map<String, String>> _doLoad() async {
    try {
      final raw = await rootBundle.load('assets/elements.csv.gz');
      final gz = raw.buffer.asUint8List();
      final bytes = gzip.decode(gz);
      final text = utf8.decode(bytes, allowMalformed: true);
      final map = <String, String>{};
      for (final line in const LineSplitter().convert(text)) {
        if (line.isEmpty) continue;
        final i = line.indexOf(',');
        if (i <= 0) continue;
        final k = line.substring(0, i);
        final v = line.substring(i + 1);
        if (k.isEmpty || v.isEmpty) continue;
        map[k] = v;
      }
      _map = map;
      return map;
    } catch (_) {
      _map = {};
      return _map!;
    }
  }

  /// Resolve [elementId] to a design id, or null if unknown.
  /// Lazy-loads the table on first call.
  Future<String?> resolve(String elementId) async {
    final m = await load();
    return m[elementId];
  }

  /// Bulk resolve: given a set of ids, returns only those that had a mapping.
  Future<Map<String, String>> resolveAll(Iterable<String> ids) async {
    final m = await load();
    final out = <String, String>{};
    for (final id in ids) {
      final v = m[id];
      if (v != null) out[id] = v;
    }
    return out;
  }
}
