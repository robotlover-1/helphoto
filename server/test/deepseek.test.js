const test = require('node:test');
const assert = require('node:assert');
const {
  DEFAULT_MODEL,
  buildDeepSeekMessages,
  callDeepSeek,
} = require('../src/deepseek.js');

function withEnv(patch, fn) {
  const saved = {};
  for (const [key, value] of Object.entries(patch)) {
    saved[key] = process.env[key];
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  return Promise.resolve()
    .then(fn)
    .finally(() => {
      for (const [key, value] of Object.entries(saved)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
    });
}

test('默认模型为支持视觉的 deepseek-flash', () => {
  assert.strictEqual(DEFAULT_MODEL, 'deepseek-flash');
});

test('intent 模式：system 要求 JSON，user 含图片与文字', () => {
  const messages = buildDeepSeekMessages({
    imageBase64: 'AAAA',
    mode: 'intent',
    intent: '日系清新',
  });

  assert.strictEqual(messages.length, 2);
  assert.strictEqual(messages[0].role, 'system');
  assert.ok(messages[0].content.includes('JSON'));
  assert.ok(!messages[0].content.includes('suggest_params'));

  const content = messages[1].content;
  const images = content.filter((p) => p.type === 'image_url');
  assert.strictEqual(images.length, 1);
  assert.strictEqual(images[0].image_url.url, 'data:image/jpeg;base64,AAAA');
  assert.ok(content.some((p) => p.type === 'text' && p.text.includes('日系清新')));
});

test('style 模式：参考图排在照片之前', () => {
  const messages = buildDeepSeekMessages({
    imageBase64: 'PHOTO',
    referenceImageBase64: 'REF',
    mode: 'style',
  });
  const images = messages[1].content.filter((p) => p.type === 'image_url');
  assert.strictEqual(images.length, 2);
  assert.ok(images[0].image_url.url.endsWith('REF'));
  assert.ok(images[1].image_url.url.endsWith('PHOTO'));
});

test('callDeepSeek 发送正确请求并解析 JSON 围栏', async () => {
  const oldFetch = globalThis.fetch;
  const captured = {};
  globalThis.fetch = async (url, init) => {
    captured.url = url;
    captured.init = init;
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: '```json\n{"params":{"exposure":5},"explanation":"e","summary":"s"}\n```',
          },
        }],
      }),
    };
  };

  try {
    await withEnv({ DEEPSEEK_API_KEY: 'test-key' }, async () => {
      const out = await callDeepSeek({ imageBase64: 'AAAA', mode: 'intent', intent: 'x' });
      assert.strictEqual(out.params.exposure, 5);
      assert.strictEqual(out.summary, 's');
    });

    assert.strictEqual(captured.url, 'https://api.deepseek.com/chat/completions');
    assert.strictEqual(captured.init.headers.authorization, 'Bearer test-key');
    const body = JSON.parse(captured.init.body);
    assert.strictEqual(body.model, 'deepseek-flash');
    assert.deepStrictEqual(body.response_format, { type: 'json_object' });
    assert.ok(body.max_tokens > 0);
  } finally {
    globalThis.fetch = oldFetch;
  }
});

test('callDeepSeek 透传 401 状态', async () => {
  const oldFetch = globalThis.fetch;
  globalThis.fetch = async () => ({
    ok: false,
    status: 401,
    text: async () => 'invalid api key',
  });

  try {
    await withEnv({ DEEPSEEK_API_KEY: 'bad' }, async () => {
      await assert.rejects(
        () => callDeepSeek({ imageBase64: 'AAAA', mode: 'intent' }),
        (err) => err.status === 401 && /invalid api key/.test(err.message),
      );
    });
  } finally {
    globalThis.fetch = oldFetch;
  }
});

test('缺少 DEEPSEEK_API_KEY 时给出明确错误', async () => {
  await withEnv({ DEEPSEEK_API_KEY: undefined }, async () => {
    await assert.rejects(
      () => callDeepSeek({ imageBase64: 'AAAA', mode: 'intent' }),
      /DEEPSEEK_API_KEY not set/,
    );
  });
});
