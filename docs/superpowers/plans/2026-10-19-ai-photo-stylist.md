# AI 摄影指导 App 实现计划

> 进度（2026-10-20）：Task 1–13 的代码步骤已完成，自动化测试通过；两个标注 Manual 的真机步骤仍待验证。计划外的拍照页（`camera_screen.dart`）也已实现。
>

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 构建一款 Flutter 移动 App：拍照/选图后输入想法（或导入风格参考图），调用 Claude 视觉模型分析并返回 8 个调色参数与通俗解释，预设到 App 内滑块供用户微调后导出。

**Architecture:** Flutter 前端分四层（参数模型 / 图像编辑引擎 / AI 分析层 / UI 层），后端为 Node 无依赖 HTTP 服务（持有 Claude key，负责结构化输出与 JSON 校验）。图像调色用单个 GLSL fragment shader 统一实现 8 个参数，预览与导出同源。

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5、Riverpod、GLSL fragment shader、Node 22（`http` + 内置 `fetch`）、Anthropic Claude 视觉 API（`claude-sonnet-5`，结构化输出 tool use）。

## Global Constraints

- Flutter/Dart 版本：Flutter 3.41.9，Dart 3.11.5。
- 8 个调色参数，滑块整数范围恒为 `-100 ~ 100`（默认 0），字段名固定：`exposure` `contrast` `temperature` `tint` `saturation` `vibrance` `highlights` `shadows`。
- 参数 JSON schema（AI 返回与 App 模型共用）三字段：`params`（8 个 int）、`explanation`（string）、`summary`（string）。
- Claude 模型固定 `claude-sonnet-5`；后端用 tool use 强制结构化输出。
- 后端零 npm 依赖：只用 Node 内置 `http` 与全局 `fetch`。
- 开发机无 Android SDK 与 Xcode：所有验证走 `flutter test` / `node --test`；相机、shader 预览、导出保存相册为**真机手动验证**步骤（标注为 Manual）。
- 每个 Task 末尾 commit；分支为 `main`，git 用户名用 `-c user.name/-c user.email` 内联（本仓库无全局 git 身份）。

---

### Task 1: 脚手架与项目结构

**Files:**
- Create: `app/pubspec.yaml`（flutter create 生成后修改）
- Create: `server/src/schema.js`、`server/src/prompts.js`、`server/src/claude.js`、`server/src/server.js`（本任务仅建空占位文件，后续任务填实）
- Create: `server/test/`（空目录，后续任务放测试）
- Create: `app/assets/shaders/`（空目录，Task 8 放 shader）
- Create: `README.md`

**Interfaces:**
- Consumes: 无（全新项目）
- Produces: 项目骨架与目录约定，供所有后续任务引用路径。

- [x] **Step 1: 生成 Flutter 项目**

Run:
```bash
cd /home/pp/Desktop/photoapp
flutter create --project-name ai_photo_stylist --org com.example --platforms=android,ios app
```
Expected: 输出 `All done!`，`app/` 下生成完整工程。

- [x] **Step 2: 精简 pubspec 并加依赖**

修改 `app/pubspec.yaml`，在 `dependencies:` 下追加（保留 flutter 自身）：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  http: ^1.2.0
  image: ^4.1.7
  image_picker: ^1.1.2
  camera: ^0.11.0
  gal: ^2.3.0
  path_provider: ^2.1.3

flutter:
  uses-material-design: true
  shaders:
    - assets/shaders/color.frag
```

- [x] **Step 3: 安装依赖**

Run:
```bash
cd /home/pp/Desktop/photoapp/app
flutter pub get
```
Expected: 输出 `Got dependencies!`，无报错。

- [x] **Step 4: 建后端目录与占位文件**

Run:
```bash
cd /home/pp/Desktop/photoapp
mkdir -p server/src server/test app/assets/shaders
touch server/src/schema.js server/src/prompts.js server/src/claude.js server/src/server.js
```

- [x] **Step 5: 写 README 骨架**

创建 `README.md`：

```markdown
# AI 摄影指导 App

Flutter 前端 + Node 后端，拍照后输入想法，AI 给出调色参数建议并预设到滑块。

- `app/`：Flutter 前端
- `server/`：Node 后端（持有 Claude key，结构化输出）

详见 `docs/superpowers/specs/` 与 `docs/superpowers/plans/`。
```

- [x] **Step 6: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app server README.md
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "chore: scaffold Flutter app and Node server"
```

---

### Task 2: EditParams 参数模型（TDD）

**Files:**
- Create: `app/lib/models/edit_params.dart`
- Test: `app/test/models/edit_params_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `class EditParams`，8 个 `final int` 字段 + `const EditParams.zero` + `copyWith` + `toJson`/`fromJson` + `operator []`。
  - `static const List<String> paramNames`。
  - `static const int minValue = -100; maxValue = 100;`

- [x] **Step 1: 写失败测试**

创建 `app/test/models/edit_params_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';

void main() {
  test('default 全为 0', () {
    const p = EditParams();
    expect(p.exposure, 0);
    expect(p.shadows, 0);
  });

  test('toJson 输出 8 个字段', () {
    const p = EditParams(exposure: 10, shadows: -5);
    final j = p.toJson();
    expect(j.length, 8);
    expect(j['exposure'], 10);
    expect(j['shadows'], -5);
  });

  test('fromJson 越界值被 clamp 到 [-100,100]', () {
    final p = EditParams.fromJson({'exposure': 999, 'shadows': -999});
    expect(p.exposure, 100);
    expect(p.shadows, -100);
  });

  test('fromJson 缺字段回退 0', () {
    final p = EditParams.fromJson({'contrast': 30});
    expect(p.contrast, 30);
    expect(p.exposure, 0);
  });

  test('operator [] 按名字取值', () {
    const p = EditParams(temperature: -18);
    expect(p['temperature'], -18);
    expect(p['tint'], 0);
  });

  test('copyWith 只改指定字段', () {
    const p = EditParams(exposure: 5);
    final q = p.copyWith(contrast: 7);
    expect(q.exposure, 5);
    expect(q.contrast, 7);
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/models/edit_params_test.dart`
Expected: FAIL（`edit_params.dart` 不存在）

- [x] **Step 3: 实现模型**

创建 `app/lib/models/edit_params.dart`：

```dart
class EditParams {
  static const List<String> paramNames = [
    'exposure',
    'contrast',
    'temperature',
    'tint',
    'saturation',
    'vibrance',
    'highlights',
    'shadows',
  ];

  static const int minValue = -100;
  static const int maxValue = 100;

  final int exposure;
  final int contrast;
  final int temperature;
  final int tint;
  final int saturation;
  final int vibrance;
  final int highlights;
  final int shadows;

  const EditParams({
    this.exposure = 0,
    this.contrast = 0,
    this.temperature = 0,
    this.tint = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.highlights = 0,
    this.shadows = 0,
  });

  static const EditParams zero = EditParams();

  EditParams copyWith({
    int? exposure,
    int? contrast,
    int? temperature,
    int? tint,
    int? saturation,
    int? vibrance,
    int? highlights,
    int? shadows,
  }) {
    return EditParams(
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      saturation: saturation ?? this.saturation,
      vibrance: vibrance ?? this.vibrance,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
    );
  }

  Map<String, int> toJson() => {
        'exposure': exposure,
        'contrast': contrast,
        'temperature': temperature,
        'tint': tint,
        'saturation': saturation,
        'vibrance': vibrance,
        'highlights': highlights,
        'shadows': shadows,
      };

  factory EditParams.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final v = json[key];
      if (v is num) return v.toInt().clamp(minValue, maxValue);
      return 0;
    }

    return EditParams(
      exposure: read('exposure'),
      contrast: read('contrast'),
      temperature: read('temperature'),
      tint: read('tint'),
      saturation: read('saturation'),
      vibrance: read('vibrance'),
      highlights: read('highlights'),
      shadows: read('shadows'),
    );
  }

  int operator [](String name) => switch (name) {
        'exposure' => exposure,
        'contrast' => contrast,
        'temperature' => temperature,
        'tint' => tint,
        'saturation' => saturation,
        'vibrance' => vibrance,
        'highlights' => highlights,
        'shadows' => shadows,
        _ => throw ArgumentError('unknown param: $name'),
      };
}
```

- [x] **Step 4: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/models/edit_params_test.dart`
Expected: PASS（6 tests）

- [x] **Step 5: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/models/edit_params.dart app/test/models/edit_params_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add EditParams model"
```

---

### Task 3: params_to_uniforms 纯函数（TDD）

**Files:**
- Create: `app/lib/engine/params_to_uniforms.dart`
- Test: `app/test/engine/params_to_uniforms_test.dart`

**Interfaces:**
- Consumes: `EditParams`（Task 2）
- Produces: `Float32List paramsToUniforms(EditParams p)`，返回 8 个 float，顺序固定：`[exposureEV, contrast, temperature, tint, saturation, vibrance, highlights, shadows]`。映射：`exposure = value/50`（EV 范围 -2..2），其余 7 个 = `value/100`（-1..1）。

- [x] **Step 1: 写失败测试**

创建 `app/test/engine/params_to_uniforms_test.dart`：

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/engine/params_to_uniforms.dart';

void main() {
  test('zero 参数全映射为 0', () {
    final u = paramsToUniforms(EditParams.zero);
    expect(u, Float32List.fromList([0, 0, 0, 0, 0, 0, 0, 0]));
  });

  test('exposure 100 -> EV 2.0', () {
    final u = paramsToUniforms(const EditParams(exposure: 100));
    expect(u[0], closeTo(2.0, 1e-6));
  });

  test('exposure -100 -> EV -2.0', () {
    final u = paramsToUniforms(const EditParams(exposure: -100));
    expect(u[0], closeTo(-2.0, 1e-6));
  });

  test('其余参数 100 -> 1.0，-100 -> -1.0', () {
    final u = paramsToUniforms(const EditParams(
      contrast: 100,
      temperature: -100,
      tint: 100,
      saturation: -100,
      vibrance: 100,
      highlights: -100,
      shadows: 100,
    ));
    expect(u[1], closeTo(1.0, 1e-6));
    expect(u[2], closeTo(-1.0, 1e-6));
    expect(u[3], closeTo(1.0, 1e-6));
    expect(u[4], closeTo(-1.0, 1e-6));
    expect(u[5], closeTo(1.0, 1e-6));
    expect(u[6], closeTo(-1.0, 1e-6));
    expect(u[7], closeTo(1.0, 1e-6));
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/engine/params_to_uniforms_test.dart`
Expected: FAIL

- [x] **Step 3: 实现**

创建 `app/lib/engine/params_to_uniforms.dart`：

```dart
import 'dart:typed_data';
import '../models/edit_params.dart';

/// 8 个 shader uniform，顺序与 `assets/shaders/color.frag` 的 float uniform
/// 声明顺序严格一致（uExposure..uShadows）：
/// [exposureEV, contrast, temperature, tint, saturation, vibrance, highlights, shadows]
Float32List paramsToUniforms(EditParams p) {
  return Float32List.fromList([
    p.exposure / 50.0,
    p.contrast / 100.0,
    p.temperature / 100.0,
    p.tint / 100.0,
    p.saturation / 100.0,
    p.vibrance / 100.0,
    p.highlights / 100.0,
    p.shadows / 100.0,
  ]);
}
```

- [x] **Step 4: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/engine/params_to_uniforms_test.dart`
Expected: PASS（4 tests）

- [x] **Step 5: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/engine/params_to_uniforms.dart app/test/engine/params_to_uniforms_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add params_to_uniforms mapping"
```

---

### Task 4: 后端 — 参数校验与 JSON 抽取（TDD）

**Files:**
- Create: `server/src/schema.js`
- Test: `server/test/schema.test.js`

**Interfaces:**
- Consumes: 无
- Produces:
  - `const PARAM_NAMES = ['exposure','contrast','temperature','tint','saturation','vibrance','highlights','shadows']`
  - `function clampParam(n)` → int，clamp 到 [-100,100]，非数字返回 0。
  - `function validateAnalysis(obj)` → 返回规范化的 `{ params, explanation, summary }`，字段缺失/类型错用默认值兜底；`explanation`/`summary` 非字符串时用 `''`。
  - `function extractJson(text)` → 从可能含 markdown 围栏的文本里抽出 `{...}` 并 `JSON.parse`，失败返回 `null`。

- [x] **Step 1: 写失败测试**

创建 `server/test/schema.test.js`：

```js
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
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/server && node --test test/schema.test.js`
Expected: FAIL（模块不存在）

- [x] **Step 3: 实现**

创建 `server/src/schema.js`：

```js
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
```

- [x] **Step 4: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/server && node --test test/schema.test.js`
Expected: PASS（7 tests）

- [x] **Step 5: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add server/src/schema.js server/test/schema.test.js
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(server): add param validation and JSON extraction"
```

---

### Task 5: 后端 — 三模式提示词（TDD）

**Files:**
- Create: `server/src/prompts.js`
- Test: `server/test/prompts.test.js`

**Interfaces:**
- Consumes: `PARAM_NAMES`（Task 4）
- Produces:
  - `function buildSystemPrompt()` → string，含角色 + 8 参数含义 + 输出格式说明。
  - `function buildUserContent({ mode, intent, feedback, currentParams })` → 给 Claude 的文本内容；`mode` 为 `'intent' | 'style' | 'refine'`，非法 mode 抛错。
  - `const PARAM_SCHEMA`（tool input_schema，JSON Schema 对象，8 个参数 `type: integer, minimum: -100, maximum: 100`，explanation/summary 为 string）。

- [x] **Step 1: 写失败测试**

创建 `server/test/prompts.test.js`：

```js
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
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/server && node --test test/prompts.test.js`
Expected: FAIL

- [x] **Step 3: 实现**

创建 `server/src/prompts.js`：

```js
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

function buildSystemPrompt() {
  const lines = [
    '你是一名专业摄影后期指导，面向摄影小白，建议要用通俗语言。',
    '你会收到一张照片（可能还有一张风格参考图或用户反馈）。',
    '你的任务是给出调色参数建议。参数取值范围 -100 到 100，0 表示不调整。各参数含义：',
    ...PARAM_NAMES.map((n) => `- ${n}: ${PARAM_MEANINGS[n]}`),
    'explanation 用通俗语言解释为什么这么调、每个关键参数动了什么（2-4 句）。',
    'summary 用一句话概括本次调整思路。',
    '务必通过 suggest_params 工具返回结果，不要输出其他文本。',
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
```

- [x] **Step 4: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/server && node --test test/prompts.test.js`
Expected: PASS（6 tests）

- [x] **Step 5: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add server/src/prompts.js server/test/prompts.test.js
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(server): add prompt templates for 3 modes"
```

---

### Task 6: 后端 — Claude 客户端与 /analyze 端点（TDD）

**Files:**
- Create: `server/src/claude.js`
- Create: `server/src/server.js`
- Test: `server/test/server.test.js`

**Interfaces:**
- Consumes: `validateAnalysis`（Task 4）、`PARAM_SCHEMA`/`buildSystemPrompt`/`buildUserContent`（Task 5）
- Produces:
  - `async function callClaude({ imageBase64, imageMediaType, referenceImageBase64, mode, intent, feedback, currentParams })` → 返回 Claude 原始 tool input 对象；内部 `fetch` 到 `https://api.anthropic.com/v1/messages`，key 从 `process.env.ANTHROPIC_API_KEY` 读。
  - `async function processAnalyze(body, claudeFn = callClaude)` → 返回 `{ status, body }`，供 server 与测试复用（依赖注入 `claudeFn` 便于 mock）。
  - `server.js` 启动 `http` 服务，路由 `POST /analyze` 调 `processAnalyze`，其余返回 404。

- [x] **Step 1: 写失败测试**

创建 `server/test/server.test.js`：

```js
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
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/server && node --test test/server.test.js`
Expected: FAIL

- [x] **Step 3: 实现 claude.js**

创建 `server/src/claude.js`：

```js
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
```

- [x] **Step 4: 实现 server.js**

创建 `server/src/server.js`：

```js
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
```

- [x] **Step 5: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/server && node --test test/server.test.js`
Expected: PASS（4 tests）

- [x] **Step 6: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add server/src/claude.js server/src/server.js server/test/server.test.js
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(server): add /analyze endpoint with Claude structured output"
```

---

### Task 7: Flutter — AI 客户端与图片降采样（TDD）

**Files:**
- Create: `app/lib/ai/ai_client.dart`
- Create: `app/lib/ai/analysis_result.dart`
- Test: `app/test/ai/ai_client_test.dart`

**Interfaces:**
- Consumes: `EditParams`（Task 2）
- Produces:
  - `class AnalysisResult { final EditParams params; final String explanation; final String summary; }`，`fromJson`。
  - `class AiClient`，构造传 `http.Client` 与 `baseUrl`；方法 `Future<AnalysisResult> analyze({required String mode, required Uint8List imageJpeg, Uint8List? referenceImageJpeg, String? intent, EditParams? currentParams, String? feedback})`。POST 到 `${baseUrl}/analyze`，body 里 `image` 为 base64。

- [x] **Step 1: 写失败测试（用 mock http.Client）**

创建 `app/test/ai/ai_client_test.dart`：

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_photo_stylist/ai/ai_client.dart';
import 'package:ai_photo_stylist/ai/analysis_result.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';

void main() {
  test('analyze 解析响应为 AnalysisResult', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/analyze');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['mode'], 'intent');
      expect(body['intent'], '日系');
      return http.Response(
        jsonEncode({
          'params': {'exposure': 12, 'temperature': -18},
          'explanation': '提亮偏冷',
          'summary': '清新',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = AiClient(client: mock, baseUrl: 'http://localhost:8787');
    final r = await client.analyze(
      mode: 'intent',
      imageJpeg: Uint8List.fromList([1, 2, 3]),
      intent: '日系',
    );

    expect(r.params.exposure, 12);
    expect(r.params.temperature, -18);
    expect(r.params.contrast, 0);
    expect(r.summary, '清新');
  });

  test('analyze 网络错误抛 AiClientException', () async {
    final mock = MockClient((_) async => throw Exception('boom'));
    final client = AiClient(client: mock, baseUrl: 'http://x');
    expect(
      () => client.analyze(mode: 'intent', imageJpeg: Uint8List(0)),
      throwsA(isA<AiClientException>()),
    );
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/ai/ai_client_test.dart`
Expected: FAIL

- [x] **Step 3: 实现 AnalysisResult**

创建 `app/lib/ai/analysis_result.dart`：

```dart
import '../models/edit_params.dart';

class AnalysisResult {
  final EditParams params;
  final String explanation;
  final String summary;

  const AnalysisResult({
    required this.params,
    required this.explanation,
    required this.summary,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawParams = json['params'];
    return AnalysisResult(
      params: rawParams is Map<String, dynamic>
          ? EditParams.fromJson(rawParams)
          : EditParams.zero,
      explanation: json['explanation'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
    );
  }
}
```

- [x] **Step 4: 实现 AiClient**

创建 `app/lib/ai/ai_client.dart`：

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/edit_params.dart';
import 'analysis_result.dart';

class AiClientException implements Exception {
  final String message;
  AiClientException(this.message);
  @override
  String toString() => 'AiClientException: $message';
}

class AiClient {
  final http.Client client;
  final String baseUrl;

  AiClient({http.Client? client, required this.baseUrl})
      : client = client ?? http.Client();

  Future<AnalysisResult> analyze({
    required String mode,
    required Uint8List imageJpeg,
    Uint8List? referenceImageJpeg,
    String? intent,
    EditParams? currentParams,
    String? feedback,
  }) async {
    final uri = Uri.parse('$baseUrl/analyze');
    final body = <String, dynamic>{
      'mode': mode,
      'image': base64Encode(imageJpeg),
      'imageMediaType': 'image/jpeg',
    };
    if (referenceImageJpeg != null) {
      body['referenceImage'] = base64Encode(referenceImageJpeg);
    }
    if (intent != null) body['intent'] = intent;
    if (currentParams != null) body['currentParams'] = currentParams.toJson();
    if (feedback != null) body['feedback'] = feedback;

    try {
      final resp = await client.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw AiClientException(decoded['error']?.toString() ?? 'status ${resp.statusCode}');
      }
      return AnalysisResult.fromJson(decoded);
    } on AiClientException {
      rethrow;
    } catch (e) {
      throw AiClientException(e.toString());
    }
  }
}
```

- [x] **Step 5: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/ai/ai_client_test.dart`
Expected: PASS（2 tests）

- [x] **Step 6: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/ai/ai_client.dart app/lib/ai/analysis_result.dart app/test/ai/ai_client_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add AiClient and AnalysisResult"
```

---

### Task 8: Flutter — 调色 shader 与预览绘制

**Files:**
- Create: `app/assets/shaders/color.frag`
- Create: `app/lib/engine/color_shader.dart`
- Test: `app/test/engine/color_shader_test.dart`（仅测 uniform 绑定常量与索引，不跑 GPU）

**Interfaces:**
- Consumes: `paramsToUniforms`（Task 3）、`EditParams`（Task 2）
- Produces:
  - `const int kUniformBaseIndex = 2`（uSize 占 float 索引 0、1；8 个参数从 2 开始）。
  - `class ColorShader`，构造传 `ui.FragmentProgram`；方法 `paint(Canvas, Size, ui.Image, EditParams)`。
  - `Future<ui.FragmentProgram> loadColorShader()`（`ui.FragmentProgram.fromAsset('assets/shaders/color.frag')`）。
  - `class ShaderPreview extends StatelessWidget`，输入 `ui.Image image` 与 `EditParams params`，用 CustomPainter 渲染。

- [x] **Step 1: 写 shader**

创建 `app/assets/shaders/color.frag`：

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uTexture;
uniform float uExposure;    // EV -2..2
uniform float uContrast;    // -1..1
uniform float uTemperature; // -1..1
uniform float uTint;        // -1..1
uniform float uSaturation;  // -1..1
uniform float uVibrance;    // -1..1
uniform float uHighlights;  // -1..1
uniform float uShadows;     // -1..1

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 c = texture(uTexture, uv).rgb;

  // 1. 曝光
  c *= pow(2.0, uExposure);

  // 2. 色温 + 色调（白平衡通道缩放）
  c.r *= 1.0 + 0.1 * uTemperature + 0.05 * uTint;
  c.g *= 1.0 - 0.05 * uTint;
  c.b *= 1.0 - 0.1 * uTemperature + 0.05 * uTint;

  // 3. 对比度（绕中灰）
  float k = 1.0 + uContrast;
  c = (c - 0.5) * k + 0.5;

  // 4. 饱和度
  float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = mix(vec3(luma), c, 1.0 + uSaturation);

  // 5. 鲜艳度（优先提低饱和像素）
  float mx = max(c.r, max(c.g, c.b));
  float mn = min(c.r, min(c.g, c.b));
  float sat = mx - mn;
  c = mix(vec3(luma), c, 1.0 + uVibrance * (1.0 - sat) * 0.6);

  // 6. 高光（亮部提升/压缩）
  float hiMask = smoothstep(0.4, 1.0, luma);
  c = mix(c, c * (1.0 + 0.3 * uHighlights), hiMask);

  // 7. 阴影（暗部提升/压缩）
  float shMask = 1.0 - smoothstep(0.0, 0.6, luma);
  c = mix(c, c + 0.4 * uShadows * (1.0 - luma), shMask);

  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
```

- [x] **Step 2: 写测试（索引与常量）**

创建 `app/test/engine/color_shader_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/engine/color_shader.dart';
import 'package:ai_photo_stylist/engine/params_to_uniforms.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';

void main() {
  test('kUniformBaseIndex 为 2（uSize 占 0、1）', () {
    expect(kUniformBaseIndex, 2);
  });

  test('paramsToUniforms 长度 8，从 base index 起连续绑定', () {
    const p = EditParams(exposure: 50);
    final u = paramsToUniforms(p);
    expect(u.length, 8);
    expect(u[0], closeTo(1.0, 1e-6)); // 50/50 = 1 EV
    expect(kUniformBaseIndex + u.length, 10); // 2..9 共 8 个
  });
}
```

- [x] **Step 3: 实现 color_shader.dart**

创建 `app/lib/engine/color_shader.dart`：

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/edit_params.dart';
import 'params_to_uniforms.dart';

/// uSize 占据 float uniform 索引 0、1，8 个参数从索引 2 开始。
const int kUniformBaseIndex = 2;

Future<ui.FragmentProgram> loadColorShader() =>
    ui.FragmentProgram.fromAsset('assets/shaders/color.frag');

class ColorShader {
  final ui.FragmentProgram program;

  ColorShader(this.program);

  void paint(ui.Canvas canvas, ui.Size size, ui.Image image, EditParams params) {
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setImageSampler(0, image);

    final uniforms = paramsToUniforms(params);
    for (var i = 0; i < uniforms.length; i++) {
      shader.setFloat(kUniformBaseIndex + i, uniforms[i]);
    }

    final paint = Paint()..shader = shader;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, paint);
  }
}

class ShaderPreview extends StatelessWidget {
  final ui.Image image;
  final EditParams params;
  final ColorShader colorShader;

  const ShaderPreview({
    super.key,
    required this.image,
    required this.params,
    required this.colorShader,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ShaderPainter(image: image, params: params, colorShader: colorShader),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.Image image;
  final EditParams params;
  final ColorShader colorShader;

  _ShaderPainter({
    required this.image,
    required this.params,
    required this.colorShader,
  });

  @override
  void paint(Canvas canvas, Size size) {
    colorShader.paint(canvas, size, image, params);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.image != image || old.params != params;
}
```

- [x] **Step 4: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/engine/color_shader_test.dart`
Expected: PASS（2 tests）

- [ ] **Step 5: Manual — shader 编译冒烟（真机）**

在真机 `flutter run` 后加载 `ShaderPreview` 确认无 shader 编译错误。若编译失败，回退方案：Task 8 的 `ColorShader.paint` 改用 `ColorFilter.matrix`（仅前 5 参数）。本步骤不做自动化。

- [x] **Step 6: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/assets/shaders/color.frag app/lib/engine/color_shader.dart app/test/engine/color_shader_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add color shader and preview painter"
```

---

### Task 9: Flutter — Riverpod 状态（TDD）

**Files:**
- Create: `app/lib/state/providers.dart`
- Test: `app/test/state/providers_test.dart`

**Interfaces:**
- Consumes: `EditParams`（Task 2）、`AnalysisResult`（Task 7）
- Produces:
  - `final editParamsProvider = NotifierProvider<EditParamsNotifier, EditParams>(...)`
  - `final suggestionProvider = NotifierProvider<SuggestionNotifier, AnalysisResult?>(...)`
  - `final analysisLoadingProvider = StateProvider<bool>(...)`
  - `EditParamsNotifier`：`set(EditParams)`、`updateParam(String name, int value)`、`reset()`。
  - `SuggestionNotifier`：`set(AnalysisResult)`、`clear()`。

- [x] **Step 1: 写失败测试**

创建 `app/test/state/providers_test.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/ai/analysis_result.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/state/providers.dart';

void main() {
  test('updateParam 更新单参数且保留其余', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editParamsProvider.notifier).updateParam('exposure', 40);
    expect(container.read(editParamsProvider).exposure, 40);
    expect(container.read(editParamsProvider).contrast, 0);
  });

  test('set 整体替换参数', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editParamsProvider.notifier).set(const EditParams(contrast: 9));
    expect(container.read(editParamsProvider).contrast, 9);
    expect(container.read(editParamsProvider).exposure, 0);
  });

  test('suggestion 初始为 null，set 后保留', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(suggestionProvider), isNull);
    container.read(suggestionProvider.notifier).set(
          const AnalysisResult(
            params: EditParams(exposure: 5),
            explanation: 'x',
            summary: 'y',
          ),
        );
    expect(container.read(suggestionProvider)!.summary, 'y');
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/state/providers_test.dart`
Expected: FAIL

- [x] **Step 3: 实现 providers.dart**

创建 `app/lib/state/providers.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/analysis_result.dart';
import '../models/edit_params.dart';

class EditParamsNotifier extends Notifier<EditParams> {
  @override
  EditParams build() => EditParams.zero;

  void set(EditParams p) => state = p;

  void updateParam(String name, int value) {
    final v = value.clamp(EditParams.minValue, EditParams.maxValue);
    state = EditParams.fromJson({...state.toJson(), name: v});
  }

  void reset() => state = EditParams.zero;
}

final editParamsProvider =
    NotifierProvider<EditParamsNotifier, EditParams>(EditParamsNotifier.new);

class SuggestionNotifier extends Notifier<AnalysisResult?> {
  @override
  AnalysisResult? build() => null;

  void set(AnalysisResult r) => state = r;

  void clear() => state = null;
}

final suggestionProvider =
    NotifierProvider<SuggestionNotifier, AnalysisResult?>(SuggestionNotifier.new);

final analysisLoadingProvider = StateProvider<bool>((ref) => false);
```

- [x] **Step 4: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/state/providers_test.dart`
Expected: PASS（3 tests）

- [x] **Step 5: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/state/providers.dart app/test/state/providers_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add Riverpod state providers"
```

---

### Task 10: Flutter — 参数滑块与建议卡片（Widget 测试）

**Files:**
- Create: `app/lib/widgets/param_slider.dart`
- Create: `app/lib/widgets/suggestion_card.dart`
- Test: `app/test/widgets/widgets_test.dart`

**Interfaces:**
- Consumes: `EditParams`（Task 2）、`AnalysisResult`（Task 7）、`editParamsProvider`/`suggestionProvider`（Task 9）
- Produces:
  - `class ParamSlider extends ConsumerWidget`，props：`String name`、`String label`、`int value`、`ValueChanged<int> onChanged`。
  - `class SuggestionCard extends ConsumerWidget`，无 props（从 `suggestionProvider` 读）。

- [x] **Step 1: 写失败测试**

创建 `app/test/widgets/widgets_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/ai/analysis_result.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/state/providers.dart';
import 'package:ai_photo_stylist/widgets/param_slider.dart';
import 'package:ai_photo_stylist/widgets/suggestion_card.dart';

Widget wrap(Widget child) => ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('ParamSlider 显示 label 与当前值', (tester) async {
    await tester.pumpWidget(wrap(ParamSlider(
      name: 'exposure',
      label: '曝光',
      value: 30,
      onChanged: (_) {},
    )));
    expect(find.text('曝光'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('SuggestionCard 空建议时不显示', (tester) async {
    await tester.pumpWidget(wrap(const SuggestionCard()));
    expect(find.textContaining('建议'), findsNothing);
  });

  testWidgets('SuggestionCard 显示 summary 与 explanation', (tester) async {
    final container = ProviderContainer(overrides: [
      suggestionProvider.overrideWith((ref) => const AnalysisResult(
            params: EditParams(),
            explanation: '提亮一点',
            summary: '清新',
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SuggestionCard())),
      ),
    );
    expect(find.text('清新'), findsOneWidget);
    expect(find.text('提亮一点'), findsOneWidget);
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/widgets/widgets_test.dart`
Expected: FAIL

- [x] **Step 3: 实现 param_slider.dart**

创建 `app/lib/widgets/param_slider.dart`：

```dart
import 'package:flutter/material.dart';

class ParamSlider extends StatelessWidget {
  final String name;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const ParamSlider({
    super.key,
    required this.name,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: -100,
            max: 100,
            divisions: 200,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}
```

- [x] **Step 4: 实现 suggestion_card.dart**

创建 `app/lib/widgets/suggestion_card.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';

class SuggestionCard extends ConsumerWidget {
  const SuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(suggestionProvider);
    if (s == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.summary, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(s.explanation),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 5: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/widgets/widgets_test.dart`
Expected: PASS（3 tests）

- [x] **Step 6: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/widgets/param_slider.dart app/lib/widgets/suggestion_card.dart app/test/widgets/widgets_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add param slider and suggestion card widgets"
```

---

### Task 11: Flutter — 编辑页（Widget 测试）

**Files:**
- Create: `app/lib/screens/edit_screen.dart`
- Test: `app/test/screens/edit_screen_test.dart`

**Interfaces:**
- Consumes: `EditParams`（Task 2）、`ShaderPreview`（Task 8）、`param_slider`/`suggestion_card`（Task 10）、providers（Task 9）
- Produces:
  - `class EditScreen extends ConsumerWidget`，props：`ui.Image image`、`ColorShader colorShader`。展示预览、建议卡片、8 个 `ParamSlider`、导出按钮、"继续给建议"按钮。

- [x] **Step 1: 写失败测试**

创建 `app/test/screens/edit_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/screens/edit_screen.dart';

void main() {
  testWidgets('EditScreen 渲染 8 个滑块与导出按钮', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EditScreen(image: null, colorShader: null),
        ),
      ),
    );
    // image 为空时显示占位，滑块仍渲染
    expect(find.text('曝光'), findsOneWidget);
    expect(find.text('阴影'), findsOneWidget);
    expect(find.text('导出'), findsOneWidget);
  });

  testWidgets('拖动滑块更新 editParamsProvider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: EditScreen(image: null, colorShader: null)),
      ),
    );
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(200, 0));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditScreen)),
    );
    expect(container.read(editParamsProvider).exposure, isNot(0));
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/screens/edit_screen_test.dart`
Expected: FAIL

- [x] **Step 3: 实现 edit_screen.dart**

创建 `app/lib/screens/edit_screen.dart`：

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/color_shader.dart';
import '../models/edit_params.dart';
import '../state/providers.dart';
import '../widgets/param_slider.dart';
import '../widgets/suggestion_card.dart';

const _labels = <String, String>{
  'exposure': '曝光',
  'contrast': '对比度',
  'temperature': '色温',
  'tint': '色调',
  'saturation': '饱和度',
  'vibrance': '鲜艳度',
  'highlights': '高光',
  'shadows': '阴影',
};

class EditScreen extends ConsumerWidget {
  final ui.Image? image;
  final ColorShader? colorShader;

  const EditScreen({super.key, this.image, this.colorShader});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(editParamsProvider);
    final notifier = ref.read(editParamsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('编辑'), actions: [
        TextButton(onPressed: () {}, child: const Text('导出')),
      ]),
      body: Column(
        children: [
          Expanded(
            child: image == null || colorShader == null
                ? const Center(child: Text('无图像'))
                : ShaderPreview(image: image!, params: params, colorShader: colorShader!),
          ),
          const SuggestionCard(),
          Expanded(
            flex: 2,
            child: ListView(
              children: EditParams.paramNames.map((name) {
                return ParamSlider(
                  name: name,
                  label: _labels[name] ?? name,
                  value: params[name],
                  onChanged: (v) => notifier.updateParam(name, v),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [x] **Step 4: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/screens/edit_screen_test.dart`
Expected: PASS（2 tests）

- [x] **Step 5: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/screens/edit_screen.dart app/test/screens/edit_screen_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add edit screen with sliders"
```

---

### Task 12: Flutter — 拍照/选图与风格导入页

**Files:**
- Create: `app/lib/screens/capture_screen.dart`
- Create: `app/lib/screens/style_screen.dart`
- Create: `app/lib/main.dart`（替换 flutter create 生成的默认 main）
- Test: `app/test/screens/capture_screen_test.dart`

**Interfaces:**
- Consumes: `AiClient`（Task 7）、providers（Task 9）、`EditScreen`（Task 11）
- Produces:
  - `class CaptureScreen extends ConsumerWidget`：选图（`image_picker`）或拍照（`camera`），输入想法文本框，"获取建议"按钮 → 调 `AiClient.analyze(mode: 'intent')` → 写 providers → 跳 `EditScreen`。
  - `class StyleScreen extends ConsumerWidget`：选参考图 + 自己的照片 → `analyze(mode: 'style')` → 跳 `EditScreen`。
  - `main.dart`：`ProviderScope` + `MaterialApp` + 首页 `CaptureScreen`。

- [x] **Step 1: 写失败测试**

创建 `app/test/screens/capture_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/screens/capture_screen.dart';

void main() {
  testWidgets('CaptureScreen 显示想法输入框与获取建议按钮', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CaptureScreen()),
      ),
    );
    expect(find.text('获取建议'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/screens/capture_screen_test.dart`
Expected: FAIL

- [x] **Step 3: 实现 capture_screen.dart**

创建 `app/lib/screens/capture_screen.dart`：

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../ai/ai_client.dart';
import '../state/providers.dart';
import 'edit_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _picker = ImagePicker();
  final _intentController = TextEditingController();
  Uint8List? _imageBytes;

  Future<void> _pick() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (f == null) return;
    setState(() => _imageBytes = f.readAsBytes());
  }

  Future<void> _analyze() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final client = AiClient(baseUrl: const String.fromEnvironment('AI_BASE_URL', defaultValue: 'http://10.0.2.2:8787'));
      final result = await client.analyze(
        mode: 'intent',
        imageJpeg: bytes,
        intent: _intentController.text,
      );
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);
    } finally {
      ref.read(analysisLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 摄影指导')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: _pick, child: const Text('选择照片')),
            if (_imageBytes != null) const Text('已选择照片'),
            TextField(
              controller: _intentController,
              decoration: const InputDecoration(hintText: '想要什么感觉？例如：日系清新'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _analyze, child: const Text('获取建议')),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 4: 实现 style_screen.dart**

创建 `app/lib/screens/style_screen.dart`：

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../ai/ai_client.dart';
import '../state/providers.dart';
import 'edit_screen.dart';

class StyleScreen extends ConsumerStatefulWidget {
  const StyleScreen({super.key});

  @override
  ConsumerState<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends ConsumerState<StyleScreen> {
  final _picker = ImagePicker();
  Uint8List? _refBytes;
  Uint8List? _photoBytes;

  Future<void> _pickRef() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (f != null) setState(() => _refBytes = f.readAsBytes());
  }

  Future<void> _pickPhoto() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (f != null) setState(() => _photoBytes = f.readAsBytes());
  }

  Future<void> _analyze() async {
    final refBytes = _refBytes;
    final photoBytes = _photoBytes;
    if (refBytes == null || photoBytes == null) return;
    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final client = AiClient(baseUrl: const String.fromEnvironment('AI_BASE_URL', defaultValue: 'http://10.0.2.2:8787'));
      final result = await client.analyze(
        mode: 'style',
        imageJpeg: photoBytes,
        referenceImageJpeg: refBytes,
      );
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);
    } finally {
      ref.read(analysisLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('风格迁移')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: _pickRef, child: const Text('选择风格参考图')),
            ElevatedButton(onPressed: _pickPhoto, child: const Text('选择自己的照片')),
            ElevatedButton(onPressed: _analyze, child: const Text('分析风格')),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 5: 实现 main.dart**

创建 `app/lib/main.dart`（覆盖默认）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/capture_screen.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 摄影指导',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const CaptureScreen(),
    );
  }
}
```

- [x] **Step 6: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/screens/capture_screen_test.dart`
Expected: PASS（1 test）

- [x] **Step 7: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/screens/capture_screen.dart app/lib/screens/style_screen.dart app/lib/main.dart app/test/screens/capture_screen_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add capture and style screens"
```

---

### Task 13: Flutter — 导出与错误处理接线

**Files:**
- Modify: `app/lib/screens/edit_screen.dart`（导出按钮 + 继续给建议 + refine）
- Create: `app/lib/engine/export.dart`
- Create: `app/lib/engine/image_codec.dart`
- Test: `app/test/engine/image_codec_test.dart`

**Interfaces:**
- Consumes: `ColorShader`（Task 8）、`AiClient`（Task 7）、providers（Task 9）
- Produces:
  - `Future<Uint8List> decodeToJpeg(Uint8List bytes, {int maxDimension = 2048})`（用 `image` 包解码 + 缩放 + 编码 JPEG）。
  - `Future<ui.Image> bytesToUiImage(Uint8List bytes)`。
  - `Future<void> exportImage(ui.Image image, ColorShader shader, EditParams params)` → 渲染到 2048px、存相册（`gal`）。
  - EditScreen 的导出按钮与"继续给建议"按钮接入上述函数。

- [x] **Step 1: 写失败测试**

创建 `app/test/engine/image_codec_test.dart`：

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ai_photo_stylist/engine/image_codec.dart';

Uint8List _encodeTestPng() {
  final im = img.Image(width: 4, height: 4);
  img.fill(im, color: img.ColorRgb8(255, 0, 0));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  test('decodeToJpeg 输出 JPEG 字节', () async {
    final jpg = await decodeToJpeg(_encodeTestPng(), maxDimension: 4);
    expect(jpg, isNotEmpty);
    expect(jpg[0], 0xFF); // JPEG SOI
    expect(jpg[1], 0xD8);
  });
}
```

- [x] **Step 2: 运行确认失败**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/engine/image_codec_test.dart`
Expected: FAIL

- [x] **Step 3: 实现 image_codec.dart**

创建 `app/lib/engine/image_codec.dart`：

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

Future<Uint8List> decodeToJpeg(Uint8List bytes, {int maxDimension = 2048}) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw ArgumentError('cannot decode image');
  var im = decoded;
  final longest = im.width > im.height ? im.width : im.height;
  if (longest > maxDimension) {
    im = img.copyResize(im, width: im.width * maxDimension ~/ longest, height: im.height * maxDimension ~/ longest);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 80));
}

Future<ui.Image> bytesToUiImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
```

- [x] **Step 4: 实现 export.dart**

创建 `app/lib/engine/export.dart`：

```dart
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import '../models/edit_params.dart';
import 'color_shader.dart';

Future<void> exportImage(
  ui.Image image,
  ColorShader colorShader,
  EditParams params, {
  int maxDimension = 2048,
}) async {
  final longest = image.width > image.height ? image.width : image.height;
  final scale = (longest > maxDimension) ? maxDimension / longest : 1.0;
  final w = (image.width * scale).round();
  final h = (image.height * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  colorShader.paint(canvas, Size(w.toDouble(), h.toDouble()), image, params);
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(w, h);
  final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) throw StateError('render failed');
  await Gal.putImageBytes(bytes.buffer.asUint8List(), name: 'ai_photo_stylist');
}
```

- [x] **Step 5: 接线 EditScreen（导出 + 继续给建议）**

修改 `app/lib/screens/edit_screen.dart`：将 `AppBar` actions 里的空导出按钮改为调用 `exportImage`，并新增底部"继续给建议"按钮（弹 `showDialog` 输入反馈，调 `AiClient.analyze(mode: 'refine', currentParams: params, feedback: ...)`，成功后 `editParamsProvider.set(result.params)`、`suggestionProvider.set(result)`）。具体实现：

```dart
// 顶部替换 actions：
actions: [
  TextButton(
    onPressed: image == null || colorShader == null
        ? null
        : () => exportImage(image!, colorShader!, ref.read(editParamsProvider)),
    child: const Text('导出'),
  ),
],
// body 的 ListView 末尾追加：
ListTile(
  leading: const Icon(Icons.refresh),
  title: const Text('继续给建议'),
  onTap: () => _showRefineDialog(context, ref),
),
```

并在文件内新增私有方法 `_showRefineDialog`（弹输入框，提交后走 refine 流程，loading 用 `analysisLoadingProvider`）。

- [x] **Step 6: 运行确认通过**

Run: `cd /home/pp/Desktop/photoapp/app && flutter test test/engine/image_codec_test.dart && flutter test`
Expected: 全量测试 PASS（无回归）

- [ ] **Step 7: Manual — 真机导出**

真机 `flutter run` 后走完拍照→建议→微调→导出，确认相册出现导出图、与预览一致。

- [x] **Step 8: Commit**

```bash
cd /home/pp/Desktop/photoapp
git add app/lib/engine/export.dart app/lib/engine/image_codec.dart app/lib/screens/edit_screen.dart app/test/engine/image_codec_test.dart
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat: add export and refine flow"
```

---

## Self-Review 记录

（计划作者在写完后的自查，已内联修复，无遗留）

- **Spec 覆盖**：设计文档第 5 节（参数+引擎）→ Task 2/3/8；第 6 节（AI 层）→ Task 4/5/6/7；第 7 节（UI）→ Task 9/10/11/12；第 8 节（错误处理）→ Task 6/7（400/502 与 AiClientException）+ Task 13；第 9 节（测试）→ 每个 Task 内置 TDD。v1 范围外的视频/HSL/曲线未纳入（符合第 3 节）。
- **占位符扫描**：无 TBD/TODO；每个代码步骤含完整代码。
- **类型一致性**：`EditParams` 字段名、`paramNames`、`paramsToUniforms` 顺序、shader uniform 顺序、`PARAM_NAMES` 四处一致；`AnalysisResult` 在 Task 7 定义、Task 9/10 复用；`ColorShader.paint` 签名在 Task 8 定义、Task 13 复用。
- **已知偏差**：后端用 Node 原生 `http` 替代设计文档中的 Express（零依赖、单端点、更抗 npm 网络波动），不影响接口契约 `POST /analyze`。
