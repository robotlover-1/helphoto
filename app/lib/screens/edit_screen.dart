import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/ai_client.dart';
import '../engine/color_shader.dart';
import '../engine/export.dart';
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
  final Uint8List? imageJpeg;

  const EditScreen({super.key, this.image, this.colorShader, this.imageJpeg});

  Future<void> _showRefineDialog(BuildContext context, WidgetRef ref) async {
    final bytes = imageJpeg;
    if (bytes == null) return;

    final feedback = await showDialog<String>(
      context: context,
      builder: (_) => const _RefineDialog(),
    );
    if (feedback == null || feedback.trim().isEmpty) return;

    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final client = AiClient(
        baseUrl: const String.fromEnvironment('AI_BASE_URL', defaultValue: 'http://10.0.2.2:8787'),
      );
      final result = await client.analyze(
        mode: 'refine',
        imageJpeg: bytes,
        currentParams: ref.read(editParamsProvider),
        feedback: feedback,
      );
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);
    } on AiClientException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分析失败，请重试')),
        );
      }
    } finally {
      ref.read(analysisLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(editParamsProvider);
    final notifier = ref.read(editParamsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑'),
        actions: [
          TextButton(
            onPressed: image == null || colorShader == null
                ? null
                : () => exportImage(image!, colorShader!, ref.read(editParamsProvider)),
            child: const Text('导出'),
          ),
        ],
      ),
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
              children: [
                ...EditParams.paramNames.map((name) {
                  return ParamSlider(
                    name: name,
                    label: _labels[name] ?? name,
                    value: params[name],
                    onChanged: (v) => notifier.updateParam(name, v),
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('继续给建议'),
                  enabled: imageJpeg != null,
                  onTap: () => _showRefineDialog(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefineDialog extends StatefulWidget {
  const _RefineDialog();

  @override
  State<_RefineDialog> createState() => _RefineDialogState();
}

class _RefineDialogState extends State<_RefineDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('继续给建议'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '哪里不满意？例如：还是太暖'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('提交'),
        ),
      ],
    );
  }
}
