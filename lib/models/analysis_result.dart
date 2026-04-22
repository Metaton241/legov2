import 'detection.dart';
import 'lego_part.dart';

class AnalysisResult {
  final List<LegoPart> inventory;
  final List<Detection> detections;
  final String pileImagePath;

  const AnalysisResult({
    required this.inventory,
    required this.detections,
    required this.pileImagePath,
  });

  /// For each inventory entry, counts detections with confidence >= [minConf].
  Map<String, int> foundCounts({double minConf = 0.5}) {
    final counts = <String, int>{};
    for (final d in detections) {
      if (d.confidence < minConf) continue;
      counts[d.partId] = (counts[d.partId] ?? 0) + 1;
    }
    return counts;
  }
}
