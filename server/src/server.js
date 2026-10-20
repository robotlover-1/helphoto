const http = require('node:http');
const { callClaude } = require('./claude.js');
const { callDeepSeek } = require('./deepseek.js');
const { validateAnalysis } = require('./schema.js');

const MODES = new Set(['intent', 'style', 'refine']);

/// AI_PROVIDER=deepseek|anthropic；未设置时优先用已配置 key 的 provider。
function resolveProvider() {
  const provider = (process.env.AI_PROVIDER || '').trim().toLowerCase();
  if (provider === 'deepseek') return callDeepSeek;
  if (provider === 'anthropic' || provider === 'claude') return callClaude;
  return process.env.DEEPSEEK_API_KEY ? callDeepSeek : callClaude;
}

async function processAnalyze(body, providerFn = resolveProvider()) {
  if (!body || !MODES.has(body.mode)) {
    return { status: 400, body: { error: 'invalid mode' } };
  }
  if (typeof body.image !== 'string' || body.image.length === 0) {
    return { status: 400, body: { error: 'image required' } };
  }
  try {
    const input = await providerFn({
      imageBase64: body.image,
      imageMediaType: body.imageMediaType,
      referenceImageBase64: body.referenceImage,
      mode: body.mode,
      intent: body.intent,
      feedback: body.feedback,
      currentParams: body.currentParams,
    });
    const validated = validateAnalysis(input);
    return { status: 200, body: validated };
  } catch (e) {
    console.error(`[analyze] ${e?.name || 'Error'}: ${e?.message || e}`);
    // 上游鉴权/限流错误原样透传，便于 App 给出针对性提示；其余按网关错误处理。
    const upstream = e && Number.isInteger(e.status) ? e.status : null;
    const status = upstream === 401 || upstream === 403 || upstream === 429 ? upstream : 502;
    return { status, body: { error: `analysis failed: ${e.message}` } };
  }
}

function createServer() {
  return http.createServer(async (req, res) => {
    if (req.method === 'POST' && req.url === '/analyze') {
      let raw = '';
      req.on('data', (c) => (raw += c));
      req.on('end', async () => {
        let parsed;
        try {
          parsed = JSON.parse(raw || '{}');
        } catch (_) {
          res.writeHead(400, { 'content-type': 'application/json' });
          return res.end(JSON.stringify({ error: 'invalid json' }));
        }
        const out = await processAnalyze(parsed);
        res.writeHead(out.status, { 'content-type': 'application/json' });
        res.end(JSON.stringify(out.body));
      });
      return;
    }
    res.writeHead(404, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: 'not found' }));
  });
}

if (require.main === module) {
  const port = process.env.PORT || 8787;
  const provider =
    (process.env.AI_PROVIDER || '').trim().toLowerCase() ||
    (process.env.DEEPSEEK_API_KEY ? 'deepseek' : 'anthropic');
  createServer().listen(port, () => {
    console.log(`server listening on :${port} (provider: ${provider})`);
  });
}

module.exports = { processAnalyze, createServer, resolveProvider };
