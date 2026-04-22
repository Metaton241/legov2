import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/analysis_snapshot.dart';

/// Persists past [AnalysisSnapshot]s to the app documents directory.
///
/// Layout:
///   <docs>/history/history.json            — index (array of snapshots)
///   <docs>/history/<id>_pile.jpg           — copied pile image
///   <docs>/history/<id>_inv.jpg            — copied inventory image
class HistoryService {
  static const _indexFile = 'history.json';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/history');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _index() async {
    final d = await _dir();
    return File('${d.path}/$_indexFile');
  }

  Future<List<AnalysisSnapshot>> loadAll() async {
    final f = await _index();
    if (!await f.exists()) return [];
    try {
      final raw = await f.readAsString();
      final list = (jsonDecode(raw) as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((m) => AnalysisSnapshot.fromJson(m.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<AnalysisSnapshot> all) async {
    final f = await _index();
    await f.writeAsString(
      jsonEncode(all.map((s) => s.toJson()).toList()),
    );
  }

  Future<AnalysisSnapshot> save({
    required List<dynamic> inventory,
    required List<dynamic> detections,
    String? setLabel,
    File? pileImage,
    File? inventoryImage,
  }) async {
    final dir = await _dir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    String? pilePath;
    if (pileImage != null && await pileImage.exists()) {
      pilePath = '${dir.path}/${id}_pile.jpg';
      await pileImage.copy(pilePath);
    }
    String? invPath;
    if (inventoryImage != null && await inventoryImage.exists()) {
      invPath = '${dir.path}/${id}_inv.jpg';
      await inventoryImage.copy(invPath);
    }

    final snap = AnalysisSnapshot(
      id: id,
      createdAt: DateTime.now(),
      setLabel: (setLabel == null || setLabel.trim().isEmpty)
          ? null
          : setLabel.trim(),
      inventory: inventory.cast(),
      detections: detections.cast(),
      pileImagePath: pilePath,
      inventoryImagePath: invPath,
    );

    final all = await loadAll();
    all.insert(0, snap);
    await _writeAll(all);
    return snap;
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    final snap = all.firstWhere(
      (s) => s.id == id,
      orElse: () => AnalysisSnapshot(
        id: id,
        createdAt: DateTime.now(),
        inventory: const [],
        detections: const [],
      ),
    );
    for (final p in [snap.pileImagePath, snap.inventoryImagePath]) {
      if (p == null) continue;
      final f = File(p);
      if (await f.exists()) await f.delete();
    }
    all.removeWhere((s) => s.id == id);
    await _writeAll(all);
  }

  /// Finds prior snapshots whose inventory fingerprint matches [fingerprint].
  Future<List<AnalysisSnapshot>> findByFingerprint(String fingerprint) async {
    if (fingerprint.isEmpty) return [];
    final all = await loadAll();
    return all.where((s) => s.fingerprint == fingerprint).toList();
  }
}
