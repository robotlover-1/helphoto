import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/engine/params_to_uniforms.dart';

void main() {
  test('zero 参数全映射为 0', () {
    final u = paramsToUniforms(EditParams.zero);
    expect(u, Float32List.fromList([0, 0, 0, 0, 0, 0, 0, 0]));
  });

  test('exposure 100 -> EV 2.0', () {
    final u = paramsToUniforms(const EditParams(exposure: 100));
    expect(u[0], closeTo(2.0, 1e-6));
  });

  test('exposure -100 -> EV -2.0', () {
    final u = paramsToUniforms(const EditParams(exposure: -100));
    expect(u[0], closeTo(-2.0, 1e-6));
  });

  test('其余参数 100 -> 1.0，-100 -> -1.0', () {
    final u = paramsToUniforms(const EditParams(
      contrast: 100,
      temperature: -100,
      tint: 100,
      saturation: -100,
      vibrance: 100,
      highlights: -100,
      shadows: 100,
    ));
    expect(u[1], closeTo(1.0, 1e-6));
    expect(u[2], closeTo(-1.0, 1e-6));
    expect(u[3], closeTo(1.0, 1e-6));
    expect(u[4], closeTo(-1.0, 1e-6));
    expect(u[5], closeTo(1.0, 1e-6));
    expect(u[6], closeTo(-1.0, 1e-6));
    expect(u[7], closeTo(1.0, 1e-6));
  });
}
