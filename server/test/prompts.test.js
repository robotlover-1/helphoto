const test = require('node:test');
const assert = require('node:assert');
const { buildSystemPrompt, buildUserContent, PARAM_SCHEMA } = require('../src/prompts.js');

test('system prompt 包含全部 8 个参数名', () => {
  const s = buildSystemPrompt();
  for (const name of ['exposure', 'contrast', 'temperature', 'tint',
    'saturation', 'vibrance', 'highlights', 'shadows']) {
    assert.ok(s.includes(name), `missing ${name}`);
  }
});

test('intent 模式拼接想法文字', () => {
  const c = buildUserContent({ mode: 'intent', intent: '日系清新' });
  assert.ok(c.includes('日系清新'));
});

test('style 模式说明是风格迁移', () => {
  const c = buildUserContent({ mode: 'style' });
  assert.ok(c.includes('参考') && c.includes('风格'));
});

test('refine 模式包含当前参数与反馈', () => {
  const c = buildUserContent({
    mode: 'refine',
    currentParams: { exposure: 10, shadows: 0 },
    feedback: '还是太暖',
  });
  assert.ok(c.includes('还是太暖'));
  assert.ok(c.includes('exposure'));
});

test('非法 mode 抛错', () => {
  assert.throws(() => buildUserContent({ mode: 'nope' }));
});

test('PARAM_SCHEMA 定义 8 个 int 参数', () => {
  const props = PARAM_SCHEMA.properties;
  assert.strictEqual(Object.keys(props.params.properties).length, 8);
  assert.strictEqual(props.params.properties.exposure.type, 'integer');
  assert.strictEqual(props.params.properties.exposure.minimum, -100);
  assert.strictEqual(props.params.properties.exposure.maximum, 100);
});

test('useTool=false 时要求只输出 JSON', () => {
  const s = buildSystemPrompt({ useTool: false });
  assert.ok(s.includes('JSON'));
  assert.ok(!s.includes('suggest_params'));
});
