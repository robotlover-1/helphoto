import 'dart:typed_data';
import '../models/edit_params.dart';

/// 8 个 shader uniform，顺序与 `assets/shaders/color.frag` 的 float uniform
/// 声明顺序严格一致（uExposure..uShadows）：
/// [exposureEV, contrast, temperature, tint, saturation, vibrance, highlights, shadows]
Float32List paramsToUniforms(EditParams p) {
  return Float32List.fromList([
    p.exposure / 50.0,
    p.contrast / 100.0,
    p.temperature / 100.0,
    p.tint / 100.0,
    p.saturation / 100.0,
    p.vibrance / 100.0,
    p.highlights / 100.0,
    p.shadows / 100.0,
  ]);
}
