import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import '../models/edit_params.dart';
import 'color_shader.dart';

Future<void> exportImage(
  ui.Image image,
  ColorShader colorShader,
  EditParams params, {
  int maxDimension = 2048,
}) async {
  final longest = image.width > image.height ? image.width : image.height;
  final scale = (longest > maxDimension) ? maxDimension / longest : 1.0;
  final w = (image.width * scale).round();
  final h = (image.height * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  colorShader.paint(canvas, Size(w.toDouble(), h.toDouble()), image, params);
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(w, h);
  final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) throw StateError('render failed');
  await Gal.putImageBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    name: 'ai_photo_stylist',
  );
}
