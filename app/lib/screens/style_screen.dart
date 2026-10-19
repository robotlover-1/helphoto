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
    if (f != null) setState(() => _refBytes = await f.readAsBytes());
  }

  Future<void> _pickPhoto() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (f != null) setState(() => _photoBytes = await f.readAsBytes());
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
