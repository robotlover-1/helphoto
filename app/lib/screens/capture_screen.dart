import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../ai/ai_client.dart';
import '../engine/color_shader.dart';
import '../engine/image_codec.dart';
import '../state/providers.dart';
import 'camera_screen.dart';
import 'edit_screen.dart';
import 'style_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _picker = ImagePicker();
  final _intentController = TextEditingController();
  Uint8List? _imageBytes;

  @override
  void dispose() {
    _intentController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (bytes != null && mounted) {
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _pick() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _analyze() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final jpeg = await decodeToJpeg(bytes, maxDimension: 1024);
      final client = AiClient(baseUrl: const String.fromEnvironment('AI_BASE_URL', defaultValue: 'http://10.0.2.2:8787'));
      final result = await client.analyze(mode: 'intent', imageJpeg: jpeg, intent: _intentController.text);
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);

      final program = await loadColorShader();
      final shader = ColorShader(program);
      final image = await bytesToUiImage(jpeg);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EditScreen(image: image, colorShader: shader, imageJpeg: jpeg),
      ));
    } on AiClientException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分析失败，请重试')));
      }
    } finally {
      ref.read(analysisLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(analysisLoadingProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 摄影指导'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StyleScreen())),
            child: const Text('风格迁移'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: _capture, child: const Text('拍照'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: _pick, child: const Text('选择照片'))),
              ],
            ),
            if (_imageBytes != null) const Text('已选择照片'),
            TextField(
              controller: _intentController,
              decoration: const InputDecoration(hintText: '想要什么感觉？例如：日系清新'),
            ),
            const SizedBox(height: 12),
            if (loading)
              const CircularProgressIndicator()
            else
              ElevatedButton(onPressed: _analyze, child: const Text('获取建议')),
          ],
        ),
      ),
    );
  }
}
