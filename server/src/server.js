const http = require('node:http');
const { callClaude } = require('./claude.js');
const { validateAnalysis } = require('./schema.js');

const MODES = new Set(['intent', 'style', 'refine']);

async function processAnalyze(body, claudeFn = callClaude) {
  if (!body || !MODES.has(body.mode)) {
    return { status: 400, body: { error: 'invalid mode' } };
  }
  if (typeof body.image !== 'string' || body.image.length === 0) {
    return { status: 400, body: { error: 'image required' } };
  }
  try {
    const input = await claudeFn({
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
    return { status: 502, body: { error: `analysis failed: ${e.message}` } };
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
  createServer().listen(port, () => {
    console.log(`server listening on :${port}`);
  });
}

module.exports = { processAnalyze, createServer };
