import 'package:flutter_test/flutter_test.dart';

import 'package:twink_lego_finder/models/lego_part.dart';

void main() {
  test('LegoPart.fromJson parses typical response', () {
    final p = LegoPart.fromJson(
        {'part_id': '3001', 'name': 'Brick 2x4', 'color': 'red', 'qty': 4});
    expect(p.partId, '3001');
    expect(p.qty, 4);
  });

  test('LegoPart.fromJson handles string qty', () {
    final p = LegoPart.fromJson({'part_id': '1', 'qty': '7'});
    expect(p.qty, 7);
  });
}
