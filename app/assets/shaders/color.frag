#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uTexture;
uniform float uExposure;    // EV -2..2
uniform float uContrast;    // -1..1
uniform float uTemperature; // -1..1
uniform float uTint;        // -1..1
uniform float uSaturation;  // -1..1
uniform float uVibrance;    // -1..1
uniform float uHighlights;  // -1..1
uniform float uShadows;     // -1..1

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 c = texture(uTexture, uv).rgb;

  // 1. 曝光
  c *= pow(2.0, uExposure);

  // 2. 色温 + 色调（白平衡通道缩放）
  c.r *= 1.0 + 0.1 * uTemperature + 0.05 * uTint;
  c.g *= 1.0 - 0.05 * uTint;
  c.b *= 1.0 - 0.1 * uTemperature + 0.05 * uTint;

  // 3. 对比度（绕中灰）
  float k = 1.0 + uContrast;
  c = (c - 0.5) * k + 0.5;

  // 4. 饱和度
  float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = mix(vec3(luma), c, 1.0 + uSaturation);

  // 5. 鲜艳度（优先提低饱和像素）
  float mx = max(c.r, max(c.g, c.b));
  float mn = min(c.r, min(c.g, c.b));
  float sat = mx - mn;
  c = mix(vec3(luma), c, 1.0 + uVibrance * (1.0 - sat) * 0.6);

  // 6. 高光（亮部提升/压缩）
  float hiMask = smoothstep(0.4, 1.0, luma);
  c = mix(c, c * (1.0 + 0.3 * uHighlights), hiMask);

  // 7. 阴影（暗部提升/压缩）
  float shMask = 1.0 - smoothstep(0.0, 0.6, luma);
  c = mix(c, c + 0.4 * uShadows * (1.0 - luma), shMask);

  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
