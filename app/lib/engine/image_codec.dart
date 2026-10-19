import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

Future<Uint8List> decodeToJpeg(Uint8List bytes, {int maxDimension = 2048}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw ArgumentError('cannot decode image');
  var im = decoded;
  final longest = im.width > im.height ? im.width : im.height;
  if (longest > maxDimension) {
    im = img.copyResize(im, width: im.width * maxDimension ~/ longest, height: im.height * maxDimension ~/ longest);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 80));
}

Future<ui.Image> bytesToUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
