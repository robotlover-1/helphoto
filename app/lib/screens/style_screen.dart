import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../ai/ai_client.dart';
import '../engine/color_shader.dart';
import '../engine/image_codec.dart';
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
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _refBytes = bytes);
  }

  Future<void> _pickPhoto() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _analyze() async {
    final refBytes = _refBytes;
    final photoBytes = _photoBytes;
    if (refBytes == null || photoBytes == null) return;
    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final refJpeg = await decodeToJpeg(refBytes, maxDimension: 1024);
      final photoJpeg = await decodeToJpeg(photoBytes, maxDimension: 1024);
      final client = AiClient(baseUrl: const String.fromEnvironment('AI_BASE_URL', defaultValue: 'http://10.0.2.2:8787'));
      final result = await client.analyze(mode: 'style', imageJpeg: photoJpeg, referenceImageJpeg: refJpeg);
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);

      final program = await loadColorShader();
      final shader = ColorShader(program);
      final image = await bytesToUiImage(photoJpeg);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EditScreen(image: image, colorShader: shader, imageJpeg: photoJpeg),
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
      appBar: AppBar(title: const Text('风格迁移')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: _pickRef, child: const Text('选择风格参考图')),
            ElevatedButton(onPressed: _pickPhoto, child: const Text('选择自己的照片')),
            if (loading)
              const CircularProgressIndicator()
            else
              ElevatedButton(onPressed: _analyze, child: const Text('分析风格')),
          ],
        ),
      ),
    );
  }
}
