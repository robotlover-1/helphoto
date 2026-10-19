import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';

void main() {
  test('default 全为 0', () {
    const p = EditParams();
    expect(p.exposure, 0);
    expect(p.shadows, 0);
  });

  test('toJson 输出 8 个字段', () {
    const p = EditParams(exposure: 10, shadows: -5);
    final j = p.toJson();
    expect(j.length, 8);
    expect(j['exposure'], 10);
    expect(j['shadows'], -5);
  });

  test('fromJson 越界值被 clamp 到 [-100,100]', () {
    final p = EditParams.fromJson({'exposure': 999, 'shadows': -999});
    expect(p.exposure, 100);
    expect(p.shadows, -100);
  });

  test('fromJson 缺字段回退 0', () {
    final p = EditParams.fromJson({'contrast': 30});
    expect(p.contrast, 30);
    expect(p.exposure, 0);
  });

  test('operator [] 按名字取值', () {
    const p = EditParams(temperature: -18);
    expect(p['temperature'], -18);
    expect(p['tint'], 0);
  });

  test('copyWith 只改指定字段', () {
    const p = EditParams(exposure: 5);
    final q = p.copyWith(contrast: 7);
    expect(q.exposure, 5);
    expect(q.contrast, 7);
  });
}
