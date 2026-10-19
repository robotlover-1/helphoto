import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/edit_params.dart';
import 'params_to_uniforms.dart';

/// uSize 占据 float uniform 索引 0、1，8 个参数从索引 2 开始。
const int kUniformBaseIndex = 2;

Future<ui.FragmentProgram> loadColorShader() =>
    ui.FragmentProgram.fromAsset('assets/shaders/color.frag');

class ColorShader {
  final ui.FragmentProgram program;

  ColorShader(this.program);

  void paint(ui.Canvas canvas, ui.Size size, ui.Image image, EditParams params) {
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setImageSampler(0, image);

    final uniforms = paramsToUniforms(params);
    for (var i = 0; i < uniforms.length; i++) {
      shader.setFloat(kUniformBaseIndex + i, uniforms[i]);
    }

    final paint = Paint()..shader = shader;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, paint);
  }
}

class ShaderPreview extends StatelessWidget {
  final ui.Image image;
  final EditParams params;
  final ColorShader colorShader;

  const ShaderPreview({
    super.key,
    required this.image,
    required this.params,
    required this.colorShader,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ShaderPainter(image: image, params: params, colorShader: colorShader),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.Image image;
  final EditParams params;
  final ColorShader colorShader;

  _ShaderPainter({
    required this.image,
    required this.params,
    required this.colorShader,
  });

  @override
  void paint(Canvas canvas, Size size) {
    colorShader.paint(canvas, size, image, params);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.image != image || old.params != params;
}
