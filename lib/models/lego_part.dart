class LegoPart {
  final String partId;
  final String name;
  final String color;
  final int qty;

  const LegoPart({
    required this.partId,
    required this.name,
    required this.color,
    required this.qty,
  });

  LegoPart copyWith({String? partId, String? name, String? color, int? qty}) =>
      LegoPart(
        partId: partId ?? this.partId,
        name: name ?? this.name,
        color: color ?? this.color,
        qty: qty ?? this.qty,
      );

  factory LegoPart.fromJson(Map<String, dynamic> j) => LegoPart(
        partId: (j['part_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        color: (j['color'] ?? '').toString(),
        qty: (j['qty'] is int)
            ? j['qty'] as int
            : int.tryParse(j['qty']?.toString() ?? '') ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'part_id': partId,
        'name': name,
        'color': color,
        'qty': qty,
      };

  @override
  String toString() => '$qty× $color $name (#$partId)';
}
