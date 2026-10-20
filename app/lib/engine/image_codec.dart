import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

/// 一次解码原图，同时产出预览图与 AI 分析图。
class PreparedImage {
  /// 长边 <= 2048 的 JPEG，用于编辑页预览与导出。
  final Uint8List previewJpeg;

  /// 长边 <= 1024 的 JPEG，仅用于发送给 AI。
  final Uint8List analysisJpeg;

  final int width;
  final int height;

  const PreparedImage({
    required this.previewJpeg,
    required this.analysisJpeg,
    required this.width,
    required this.height,
  });
}

img.Image _resizeToLongest(img.Image source, int longestSide) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= longestSide) return source;
  final width = (source.width * longestSide ~/ longest).clamp(1, source.width);
  final height = (source.height * longestSide ~/ longest).clamp(1, source.height);
  return img.copyResize(source, width: width, height: height);
}

Future<PreparedImage> prepareImage(
  Uint8List bytes, {
  int previewDimension = 2048,
  int analysisDimension = 1024,
}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw ArgumentError('cannot decode image');
  if (decoded.width <= 0 || decoded.height <= 0) {
    throw ArgumentError('invalid image size');
  }

  final preview = _resizeToLongest(decoded, previewDimension);
  final analysis = _resizeToLongest(preview, analysisDimension);

  return PreparedImage(
    previewJpeg: Uint8List.fromList(img.encodeJpg(preview, quality: 92)),
    analysisJpeg: Uint8List.fromList(img.encodeJpg(analysis, quality: 80)),
    width: preview.width,
    height: preview.height,
  );
}

Future<Uint8List> decodeToJpeg(Uint8List bytes, {int maxDimension = 2048}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw ArgumentError('cannot decode image');
  final im = _resizeToLongest(decoded, maxDimension);
  return Uint8List.fromList(img.encodeJpg(im, quality: 80));
}

Future<ui.Image> bytesToUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
