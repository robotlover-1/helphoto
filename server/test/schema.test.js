const test = require('node:test');
const assert = require('node:assert');
const { PARAM_NAMES, clampParam, validateAnalysis, extractJson } = require('../src/schema.js');

test('PARAM_NAMES 为 8 个固定字段', () => {
  assert.deepStrictEqual(PARAM_NAMES, [
    'exposure', 'contrast', 'temperature', 'tint',
    'saturation', 'vibrance', 'highlights', 'shadows',
  ]);
});

test('clampParam 越界被 clamp，非数字返回 0', () => {
  assert.strictEqual(clampParam(999), 100);
  assert.strictEqual(clampParam(-999), -100);
  assert.strictEqual(clampParam(12.7), 13);
  assert.strictEqual(clampParam('x'), 0);
  assert.strictEqual(clampParam(undefined), 0);
});

test('validateAnalysis 填充缺失字段为 0', () => {
  const out = validateAnalysis({ params: { contrast: 30 } });
  assert.strictEqual(out.params.contrast, 30);
  assert.strictEqual(out.params.exposure, 0);
  assert.strictEqual(out.explanation, '');
  assert.strictEqual(out.summary, '');
});

test('validateAnalysis 保留 explanation 与 summary', () => {
  const out = validateAnalysis({
    params: { saturation: 8 },
    explanation: '提亮一点',
    summary: '清新',
  });
  assert.strictEqual(out.explanation, '提亮一点');
  assert.strictEqual(out.summary, '清新');
});

test('extractJson 解析裸 JSON', () => {
  assert.deepStrictEqual(extractJson('{"a":1}'), { a: 1 });
});

test('extractJson 解析 markdown 围栏内 JSON', () => {
  assert.deepStrictEqual(extractJson('```json\n{"a":1}\n```'), { a: 1 });
});

test('extractJson 失败返回 null', () => {
  assert.strictEqual(extractJson('not json'), null);
});
