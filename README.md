# AI 摄影指导 App

Flutter 前端 + Node 后端，拍照后输入想法，AI 给出调色参数建议并预设到滑块。

- `app/`：Flutter 前端
- `server/`：Node 后端（持有 Claude key，结构化输出）

详见 `docs/superpowers/specs/` 与 `docs/superpowers/plans/`。

## 环境要求

- Flutter 3.41.9 / Dart 3.11.5
- Node.js 22（后端零 npm 依赖，使用内置 `fetch` 与 `node --test`）
- Android SDK（构建 APK）；iOS 打包需要 macOS + Xcode

## 后端

```bash
cd server
cp .env.example .env        # 填入 DEEPSEEK_API_KEY（或 ANTHROPIC_API_KEY）
npm run dev                 # 等价于 node --env-file=.env src/server.js
```

### 模型配置

用 `AI_PROVIDER` 切换 provider，默认 `deepseek`：

| 变量 | 说明 |
| --- | --- |
| `AI_PROVIDER` | `deepseek` 或 `anthropic` |
| `DEEPSEEK_API_KEY` | DeepSeek 密钥 |
| `DEEPSEEK_MODEL` | 默认 `deepseek-flash`（V4.1，**支持图片输入**） |
| `DEEPSEEK_BASE_URL` | 默认 `https://api.deepseek.com` |
| `ANTHROPIC_API_KEY` | `AI_PROVIDER=anthropic` 时使用 |

> 注意：DeepSeek 只有 `deepseek-flash`（以及旧名 `deepseek-v4-flash-vision-exp`）支持图片；
> `deepseek-v4-pro`、旧的 `deepseek-chat` 等文本模型不接受图片，会调用失败。

不依赖 `.env` 时可直接：

```bash
AI_PROVIDER=deepseek DEEPSEEK_API_KEY=sk-... PORT=8787 node src/server.js
```

监听 `PORT`（默认 `8787`），唯一端点 `POST /analyze`：

```json
{ "mode": "intent|style|refine", "image": "<base64>", "referenceImage": "<base64>",
  "intent": "日系清新", "currentParams": { "...": 0 }, "feedback": "还是太暖" }
```

测试（注意用 glob，`node --test test/` 在 Node 22 下会失败）：

```bash
cd server && npm test       # node --test test/*.test.js
```

## 前端

```bash
cd app
flutter pub get
flutter test
```

模拟器运行（`10.0.2.2` 是 Android 模拟器访问宿主机的地址）：

```bash
flutter run
```

真机通过 USB 调试时推荐用 `adb reverse`，无需关心电脑 IP（虚拟机 NAT 网络也能用）：

```bash
adb reverse tcp:8787 tcp:8787          # 手机的 127.0.0.1:8787 → 电脑的 8787
cd app
flutter run --dart-define=AI_BASE_URL=http://127.0.0.1:8787
```

若手机与电脑处于同一局域网，也可改用电脑 IP：

```bash
flutter run --dart-define=AI_BASE_URL=http://192.168.1.10:8787
```

后端默认监听所有网卡，无需额外绑定；如系统防火墙开启，需放行 8787 端口。

构建 APK（产物在 `app/build/app/outputs/flutter-apk/`）：

```bash
cd app
# 真机 + adb reverse 时（推荐）
flutter build apk --debug --dart-define=AI_BASE_URL=http://127.0.0.1:8787
# 或使用局域网 IP
flutter build apk --debug --dart-define=AI_BASE_URL=http://192.168.1.10:8787
# Release
flutter build apk --release --dart-define=AI_BASE_URL=http://127.0.0.1:8787
```

> 国内网络下 Gradle 发行版可能下载失败（`services.gradle.org` 会跳转 GitHub）。可先手动把发行版解压到
> `~/.gradle/wrapper/dists/gradle-8.14-all/<hash>/` 并创建 `gradle-8.14-all.zip.ok`，
> 或把 `android/gradle/wrapper/gradle-wrapper.properties` 的 `distributionUrl` 换成可用镜像（如腾讯云）。

## 手工验证清单（需真机）

- [ ] 拍照页正常取景、拍照后返回照片
- [ ] 选图/拍照 → 输入想法 → 获取建议 → 跳转编辑页且滑块已预设
- [ ] 拖动任意滑块，预览实时更新（shader 编译无报错）
- [ ] 风格迁移：两张图 → 分析风格 → 参数迁移
- [ ] 「继续给建议」输入反馈后滑块刷新
- [ ] 导出后相册出现成图，且与预览效果一致
- [ ] 拒绝相机/相册权限时提示清晰

## 目录

```text
app/lib/
  models/    参数模型
  engine/    shader、uniform 映射、图片编解码、导出
  ai/        Claude 客户端
  state/     Riverpod providers
  screens/   拍照/选图、风格迁移、编辑
  widgets/   滑块、建议卡片
server/src/  schema 校验、提示词、Claude 调用、HTTP 服务
```
