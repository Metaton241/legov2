class Detection {
  final String partId;
  final List<double> bbox; // [x, y, w, h] normalized 0..1
  final double confidence;
  final String? name; // optional descriptive name (from inventory or Brickognize)
  final bool matched; // true when partId belongs to the requested inventory

  const Detection({
    required this.partId,
    required this.bbox,
    required this.confidence,
    this.name,
    this.matched = true,
  });

  double get x => bbox[0];
  double get y => bbox[1];
  double get w => bbox[2];
  double get h => bbox[3];

  factory Detection.fromJson(Map<String, dynamic> j) {
    final raw = (j['bbox'] as List?) ?? const [];
    final nums =
        raw.map((e) => (e is num) ? e.toDouble() : 0.0).toList(growable: false);
    final bbox = nums.length == 4 ? nums : <double>[0, 0, 0, 0];
    return Detection(
      partId: (j['part_id'] ?? '').toString(),
      bbox: bbox,
      confidence: (j['confidence'] is num)
          ? (j['confidence'] as num).toDouble()
          : 0.0,
      name: j['name']?.toString(),
      matched: j['matched'] != false, // default true for backward-compat
    );
  }

  Map<String, dynamic> toJson() => {
        'part_id': partId,
        'bbox': bbox,
        'confidence': confidence,
        if (name != null) 'name': name,
        'matched': matched,
      };
}
