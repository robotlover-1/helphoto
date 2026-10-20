import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ai_photo_stylist/engine/image_codec.dart';

Uint8List _encodeTestPng({int width = 4, int height = 4}) {
  final im = img.Image(width: width, height: height);
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

  test('prepareImage 同时输出 2048 预览与 1024 分析图', () async {
    final prepared = await prepareImage(
      _encodeTestPng(width: 40, height: 20),
      previewDimension: 20,
      analysisDimension: 10,
    );

    final preview = img.decodeJpg(prepared.previewJpeg)!;
    final analysis = img.decodeJpg(prepared.analysisJpeg)!;

    expect(preview.width, 20);
    expect(preview.height, 10);
    expect(analysis.width, 10);
    expect(analysis.height, 5);
    expect(prepared.width, 20);
    expect(prepared.height, 10);
    expect(prepared.previewJpeg[0], 0xFF);
    expect(prepared.analysisJpeg[0], 0xFF);
  });

  test('prepareImage 对无法解码的数据抛错', () async {
    expect(
      () => prepareImage(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ArgumentError>()),
    );
  });
}
