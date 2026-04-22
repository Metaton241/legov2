import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  /// Compresses [source] to JPEG with longest side <= [maxSide], returns the
  /// new file path. Also returns the original when compression fails.
  static Future<File> compress(File source, {int maxSide = 1600, int quality = 85}) async {
    final dir = await getTemporaryDirectory();
    final target =
        '${dir.path}/cmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      target,
      quality: quality,
      minWidth: maxSide,
      minHeight: maxSide,
      format: CompressFormat.jpeg,
    );
    if (result == null) return source;
    return File(result.path);
  }

  static Future<String> toBase64(File image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  static Future<String> compressAndEncode(File source,
      {int maxSide = 1600, int quality = 85}) async {
    final compressed = await compress(source, maxSide: maxSide, quality: quality);
    return toBase64(compressed);
  }
}
