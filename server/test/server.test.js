const test = require('node:test');
const assert = require('node:assert');
const { processAnalyze } = require('../src/server.js');

test('processAnalyze 成功路径：解析 tool input 并校验', async () => {
  const fakeClaude = async () => ({ params: { exposure: 12 }, explanation: '提亮', summary: '亮' });
  const res = await processAnalyze({
    mode: 'intent', image: 'AAAA', intent: '日系',
  }, fakeClaude);
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.params.exposure, 12);
  assert.strictEqual(res.body.params.contrast, 0);
  assert.strictEqual(res.body.summary, '亮');
});

test('processAnalyze 非法 mode 返回 400', async () => {
  const fakeClaude = async () => ({});
  const res = await processAnalyze({ mode: 'nope', image: 'AAAA' }, fakeClaude);
  assert.strictEqual(res.status, 400);
});

test('processAnalyze Claude 抛错返回 502', async () => {
  const fakeClaude = async () => { throw new Error('api down'); };
  const res = await processAnalyze({ mode: 'intent', image: 'AAAA' }, fakeClaude);
  assert.strictEqual(res.status, 502);
});

test('processAnalyze 缺 image 返回 400', async () => {
  const fakeClaude = async () => ({});
  const res = await processAnalyze({ mode: 'intent' }, fakeClaude);
  assert.strictEqual(res.status, 400);
});
