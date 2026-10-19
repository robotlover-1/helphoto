const { PARAM_SCHEMA, buildSystemPrompt, buildUserContent } = require('./prompts.js');

const MODEL = 'claude-sonnet-5';

function imageBlock(base64, mediaType) {
  return { type: 'image', source: { type: 'base64', media_type: mediaType, data: base64 } };
}

async function callClaude({
  imageBase64,
  imageMediaType = 'image/jpeg',
  referenceImageBase64,
  mode,
  intent,
  feedback,
  currentParams,
}) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error('ANTHROPIC_API_KEY not set');

  const content = [];
  if (referenceImageBase64) content.push(imageBlock(referenceImageBase64, imageMediaType));
  content.push(imageBlock(imageBase64, imageMediaType));
  content.push({ type: 'text', text: buildUserContent({ mode, intent, feedback, currentParams }) });

  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 1024,
      system: buildSystemPrompt(),
      messages: [{ role: 'user', content }],
      tools: [{ name: 'suggest_params', description: '返回调色参数建议', input_schema: PARAM_SCHEMA }],
      tool_choice: { type: 'tool', name: 'suggest_params' },
    }),
  });

  if (!resp.ok) {
    throw new Error(`claude api error ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  const toolUse = (data.content || []).find((b) => b.type === 'tool_use');
  if (!toolUse) throw new Error('no tool_use in response');
  return toolUse.input;
}

module.exports = { callClaude };
