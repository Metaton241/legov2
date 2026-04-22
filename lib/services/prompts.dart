class Prompts {
  static const String parseInventory = '''
You are a parser for a LEGO instruction inventory page.
The image shows a table of parts used in a LEGO set. For EACH distinct part row, return strict JSON:

{
  "parts": [
    {"part_id": "3001", "name": "Brick 2x4", "color": "red", "qty": 4}
  ]
}

Rules:
- part_id: the 4-5 digit design id printed next to the rendered part image.
- name: short descriptive name (e.g. "Brick 2x4", "Plate 1x2", "Tile 2x2 Round").
- color: lowercase english LEGO color (red, blue, yellow, black, white, tan, lightBluishGray, darkBluishGray, orange, green, lime, brown, ...). If unsure, use your best guess.
- qty: positive integer written near that part in the table.
- Do NOT invent parts that are not on the page.
- If a character is ambiguous, output "?" for that character position.
- Respond with ONLY the JSON object, no markdown fences, no commentary.
''';

  /// Builds the second-stage prompt given the list of parts to locate.
  static String findParts(String partsJson) => '''
На фото куча деталей LEGO. Тебе дан список искомых деталей:
$partsJson

Найди КАЖДЫЙ экземпляр каждой детали на фото. Верни JSON:
{
  "detections": [
    {"part_id": "3001", "bbox": [x, y, w, h], "confidence": 0.85}
  ]
}
Правила:
- bbox в НОРМАЛИЗОВАННЫХ координатах [0..1] от размера изображения
- x,y — левый верхний угол
- confidence от 0 до 1
- Верни все найденные экземпляры (для qty=3 могут быть 0–5 штук)
- Если не уверен — confidence < 0.5
- Возвращай ТОЛЬКО JSON.
''';
}
