const { buildSystemPrompt, buildUserContent } = require('./prompts.js');
const { extractJson } = require('./schema.js');

const DEFAULT_BASE_URL = 'https://api.deepseek.com';
// deepseek-flash（V4.1）是支持图片输入的模型；deepseek-v4-pro 等文本模型不接受图片。
const DEFAULT_MODEL = 'deepseek-flash';

class DeepSeekApiError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'DeepSeekApiError';
    this.status = status;
  }
}

function imagePart(base64, mediaType = 'image/jpeg') {
  return {
    type: 'image_url',
    image_url: { url: `data:${mediaType};base64,${base64}` },
  };
}

/// 组装 OpenAI 兼容的 messages：参考图在前、照片在后，最后是文字指令。
function buildDeepSeekMessages({
  imageBase64,
  imageMediaType = 'image/jpeg',
  referenceImageBase64,
  mode,
  intent,
  feedback,
  currentParams,
}) {
  const content = [];
  if (referenceImageBase64) {
    content.push(imagePart(referenceImageBase64, imageMediaType));
  }
  content.push(imagePart(imageBase64, imageMediaType));
  content.push({
    type: 'text',
    text: buildUserContent({ mode, intent, feedback, currentParams }),
  });

  return [
    { role: 'system', content: buildSystemPrompt({ useTool: false }) },
    { role: 'user', content },
  ];
}

async function callDeepSeek(opts) {
  const key = process.env.DEEPSEEK_API_KEY;
  if (!key) throw new Error('DEEPSEEK_API_KEY not set');

  const baseUrl = (process.env.DEEPSEEK_BASE_URL || DEFAULT_BASE_URL).replace(/\/+$/, '');
  const model = process.env.DEEPSEEK_MODEL || DEFAULT_MODEL;

  const resp = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      model,
      messages: buildDeepSeekMessages(opts),
      response_format: { type: 'json_object' },
      max_tokens: 1024,
    }),
  });

  if (!resp.ok) {
    throw new DeepSeekApiError(
      resp.status,
      `deepseek api error ${resp.status}: ${await resp.text()}`,
    );
  }

  const data = await resp.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || content.length === 0) {
    throw new Error('no content in deepseek response');
  }
  const parsed = extractJson(content);
  if (!parsed || typeof parsed !== 'object') {
    throw new Error('deepseek returned invalid JSON');
  }
  return parsed;
}

module.exports = {
  DEFAULT_BASE_URL,
  DEFAULT_MODEL,
  DeepSeekApiError,
  buildDeepSeekMessages,
  callDeepSeek,
};
