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
    final bytes = await f.readAsBytes();
    setState(() => _imageBytes = bytes);
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
