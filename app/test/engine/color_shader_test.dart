import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/engine/color_shader.dart';
import 'package:ai_photo_stylist/engine/params_to_uniforms.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';

void main() {
  test('kUniformBaseIndex 为 2（uSize 占 0、1）', () {
    expect(kUniformBaseIndex, 2);
  });

  test('paramsToUniforms 长度 8，从 base index 起连续绑定', () {
    const p = EditParams(exposure: 50);
    final u = paramsToUniforms(p);
    expect(u.length, 8);
    expect(u[0], closeTo(1.0, 1e-6)); // 50/50 = 1 EV
    expect(kUniformBaseIndex + u.length, 10); // 2..9 共 8 个
  });
}
