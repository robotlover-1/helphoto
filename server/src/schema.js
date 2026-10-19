const PARAM_NAMES = [
  'exposure', 'contrast', 'temperature', 'tint',
  'saturation', 'vibrance', 'highlights', 'shadows',
];

function clampParam(n) {
  if (typeof n !== 'number' || !Number.isFinite(n)) return 0;
  return Math.max(-100, Math.min(100, Math.round(n)));
}

function validateAnalysis(obj) {
  const raw = (obj && typeof obj === 'object' && obj.params) || {};
  const params = {};
  for (const name of PARAM_NAMES) {
    params[name] = clampParam(raw[name]);
  }
  return {
    params,
    explanation: typeof obj?.explanation === 'string' ? obj.explanation : '',
    summary: typeof obj?.summary === 'string' ? obj.summary : '',
  };
}

function extractJson(text) {
  if (typeof text !== 'string') return null;
  try {
    return JSON.parse(text);
  } catch (_) {
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      return JSON.parse(match[0]);
    } catch (_) {
      return null;
    }
  }
}

module.exports = { PARAM_NAMES, clampParam, validateAnalysis, extractJson };
