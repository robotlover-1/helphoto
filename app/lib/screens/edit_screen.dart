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
import '../widgets/retry_snack_bar.dart';
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

class EditScreen extends ConsumerStatefulWidget {
  final ui.Image? image;
  final ColorShader? colorShader;
  final Uint8List? imageJpeg;

  const EditScreen({super.key, this.image, this.colorShader, this.imageJpeg});

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  bool _comparing = false;

  bool get _hasPhoto => widget.image != null && widget.colorShader != null;

  Future<void> _showRefineDialog() async {
    if (widget.imageJpeg == null) return;

    final feedback = await showDialog<String>(
      context: context,
      builder: (_) => const _RefineDialog(),
    );
    if (feedback == null || feedback.trim().isEmpty || !mounted) return;
    await _runRefine(feedback);
  }

  Future<void> _runRefine(String feedback) async {
    final bytes = widget.imageJpeg;
    if (bytes == null) return;

    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final client = AiClient(
        baseUrl: const String.fromEnvironment(
          'AI_BASE_URL',
          defaultValue: 'http://10.0.2.2:8787',
        ),
      );
      final result = await client.analyze(
        mode: 'refine',
        imageJpeg: bytes,
        currentParams: ref.read(editParamsProvider),
        feedback: feedback,
      );
      if (!mounted) return;
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);
    } on AiClientException catch (e) {
      if (mounted) {
        showRetrySnackBar(context, e.message, () => _runRefine(feedback));
      }
    } catch (_) {
      if (mounted) {
        showRetrySnackBar(context, '处理失败，请重试', () => _runRefine(feedback));
      }
    } finally {
      if (mounted) {
        ref.read(analysisLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _export() async {
    final img = widget.image;
    final shader = widget.colorShader;
    if (img == null || shader == null) return;
    try {
      await exportImage(img, shader, ref.read(editParamsProvider));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已导出到相册')),
        );
      }
    } catch (_) {
      if (mounted) {
        showRetrySnackBar(context, '导出失败，请检查相册权限', _export);
      }
    }
  }

  void _resetToSuggestion() {
    final suggested = ref.read(suggestionProvider)?.params ?? EditParams.zero;
    ref.read(editParamsProvider.notifier).set(suggested);
  }

  void _startCompare() {
    if (!_hasPhoto || _comparing) return;
    setState(() => _comparing = true);
  }

  void _endCompare() {
    if (!_comparing) return;
    setState(() => _comparing = false);
  }

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(editParamsProvider);
    final notifier = ref.read(editParamsProvider.notifier);
    final loading = ref.watch(analysisLoadingProvider);
    final displayParams = _comparing ? EditParams.zero : params;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑'),
        actions: [
          IconButton(
            onPressed: _hasPhoto ? _resetToSuggestion : null,
            tooltip: '重置为建议',
            icon: const Icon(Icons.restart_alt),
          ),
          TextButton(
            onPressed: _hasPhoto ? _export : null,
            child: const Text('导出'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(flex: 3, child: _buildPreview(displayParams)),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
              child: Column(
                children: [
                  const SuggestionCard(),
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
                    enabled: widget.imageJpeg != null && !loading,
                    onTap: _showRefineDialog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(EditParams displayParams) {
    final image = widget.image;
    final shader = widget.colorShader;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: image == null || shader == null
                ? const Center(
                    child: Text('无图像', style: TextStyle(color: Colors.white70)),
                  )
                : Center(
                    child: AspectRatio(
                      aspectRatio: image.width / image.height,
                      child: RepaintBoundary(
                        child: ShaderPreview(
                          image: image,
                          params: displayParams,
                          colorShader: shader,
                        ),
                      ),
                    ),
                  ),
          ),
          if (_hasPhoto)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: _CompareButton(
                  comparing: _comparing,
                  onStart: _startCompare,
                  onEnd: _endCompare,
                ),
              ),
            ),
          if (_comparing)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '原图',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompareButton extends StatelessWidget {
  final bool comparing;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _CompareButton({
    required this.comparing,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onStart(),
      onPointerUp: (_) => onEnd(),
      onPointerCancel: (_) => onEnd(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              comparing ? '原图' : '按住对比',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
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
