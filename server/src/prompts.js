const { PARAM_NAMES } = require('./schema.js');

const PARAM_MEANINGS = {
  exposure: '曝光：整体明暗，正=更亮，负=更暗',
  contrast: '对比度：明暗反差，正=更强，负=更柔',
  temperature: '色温：正=偏暖(黄)，负=偏冷(蓝)',
  tint: '色调：正=偏品红，负=偏绿',
  saturation: '饱和度：颜色浓淡，正=更浓，负=更灰',
  vibrance: '鲜艳度：优先提低饱和色，正=更鲜活',
  highlights: '高光：正=提亮部，负=压亮部',
  shadows: '阴影：正=提暗部，负=压暗部',
};

const PARAM_SCHEMA = {
  type: 'object',
  properties: {
    params: {
      type: 'object',
      properties: Object.fromEntries(
        PARAM_NAMES.map((n) => [n, { type: 'integer', minimum: -100, maximum: 100 }])
      ),
      required: PARAM_NAMES,
    },
    explanation: { type: 'string' },
    summary: { type: 'string' },
  },
  required: ['params', 'explanation', 'summary'],
};

function buildSystemPrompt({ useTool = true } = {}) {
  const lines = [
    '你是一名专业摄影后期指导，面向摄影小白，建议要用通俗语言。',
    '你会收到一张照片（可能还有一张风格参考图或用户反馈）。',
    '你的任务是给出调色参数建议。参数取值范围 -100 到 100，0 表示不调整。各参数含义：',
    ...PARAM_NAMES.map((n) => `- ${n}: ${PARAM_MEANINGS[n]}`),
    'explanation 用通俗语言解释为什么这么调、每个关键参数动了什么（2-4 句）。',
    'summary 用一句话概括本次调整思路。',
    useTool
      ? '务必通过 suggest_params 工具返回结果，不要输出其他文本。'
      : '只输出一个 JSON 对象，形如 {"params": {...8 个整数...}, "explanation": "...", "summary": "..."}，不要输出任何其他文本。',
  ];
  return lines.join('\n');
}

function buildUserContent({ mode, intent, feedback, currentParams }) {
  switch (mode) {
    case 'intent':
      return `用户想实现的效果（自然语言）：${intent || ''}\n请根据照片给出让照片符合该想法的调色参数建议。`;
    case 'style':
      return '第一张图是用户想要实现风格的参考图，第二张图是用户自己的照片。\n请分析参考图的调色风格，给出让第二张照片朝该风格靠拢的调色参数。';
    case 'refine':
      return `用户对当前结果不满意，反馈：${feedback || ''}\n当前参数：${JSON.stringify(currentParams || {})}\n请基于当前参数给出新的绝对参数建议（不是增量）。`;
    default:
      throw new Error(`unknown mode: ${mode}`);
  }
}

module.exports = { PARAM_SCHEMA, buildSystemPrompt, buildUserContent };
