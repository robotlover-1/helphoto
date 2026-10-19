import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ai_photo_stylist/engine/image_codec.dart';

Uint8List _encodeTestPng() {
  final im = img.Image(width: 4, height: 4);
  img.fill(im, color: img.ColorRgb8(255, 0, 0));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  test('decodeToJpeg 输出 JPEG 字节', () async {
    final jpg = await decodeToJpeg(_encodeTestPng(), maxDimension: 4);
    expect(jpg, isNotEmpty);
    expect(jpg[0], 0xFF); // JPEG SOI
    expect(jpg[1], 0xD8);
  });
}
