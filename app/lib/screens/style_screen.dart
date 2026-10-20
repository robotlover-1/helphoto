import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/ai_client.dart';
import '../engine/color_shader.dart';
import '../engine/image_codec.dart';
import '../models/picked_photo.dart';
import '../state/providers.dart';
import '../widgets/retry_snack_bar.dart';
import '../widgets/selected_photo_card.dart';
import 'edit_screen.dart';
import 'photo_gallery_screen.dart';

class StyleScreen extends ConsumerStatefulWidget {
  const StyleScreen({super.key});

  @override
  ConsumerState<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends ConsumerState<StyleScreen> {
  PickedPhoto? _reference;
  PickedPhoto? _photo;

  Future<PickedPhoto?> _pick(String label) async {
    try {
      final bytes = await PhotoGalleryScreen.pick(context);
      if (bytes == null || bytes.isEmpty) return null;
      return PickedPhoto(bytes: bytes, sourceLabel: label);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取相册，请检查照片权限')),
        );
      }
      return null;
    }
  }

  Future<void> _pickReference() async {
    final picked = await _pick('参考图');
    if (picked != null && mounted) setState(() => _reference = picked);
  }

  Future<void> _pickPhoto() async {
    final picked = await _pick('我的照片');
    if (picked != null && mounted) setState(() => _photo = picked);
  }

  Future<void> _analyze() async {
    final reference = _reference;
    final photo = _photo;
    if (reference == null || photo == null) return;

    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final preparedRef = await prepareImage(reference.bytes);
      final preparedPhoto = await prepareImage(photo.bytes);
      final client = AiClient(
        baseUrl: const String.fromEnvironment(
          'AI_BASE_URL',
          defaultValue: 'http://10.0.2.2:8787',
        ),
      );
      final result = await client.analyze(
        mode: 'style',
        imageJpeg: preparedPhoto.analysisJpeg,
        referenceImageJpeg: preparedRef.analysisJpeg,
      );
      if (!mounted) return;
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);

      final program = await loadColorShader();
      final shader = ColorShader(program);
      final image = await bytesToUiImage(preparedPhoto.previewJpeg);
      if (!mounted) {
        image.dispose();
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EditScreen(
          image: image,
          colorShader: shader,
          imageJpeg: preparedPhoto.analysisJpeg,
        ),
      ));
      image.dispose();
    } on AiClientException catch (e) {
      if (mounted) showRetrySnackBar(context, e.message, _analyze);
    } catch (_) {
      if (mounted) showRetrySnackBar(context, '处理照片失败，请重试', _analyze);
    } finally {
      if (mounted) {
        ref.read(analysisLoadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(analysisLoadingProvider);
    final reference = _reference;
    final photo = _photo;
    final ready = reference != null && photo != null;

    return Scaffold(
      appBar: AppBar(title: const Text('风格迁移')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Slot(
                title: '风格参考图',
                photo: reference,
                emptyLabel: '选择风格参考图',
                onPick: _pickReference,
                onRemove: () => setState(() => _reference = null),
              ),
              const SizedBox(height: 12),
              _Slot(
                title: '我的照片',
                photo: photo,
                emptyLabel: '选择自己的照片',
                onPick: _pickPhoto,
                onRemove: () => setState(() => _photo = null),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: ready ? _analyze : null,
                  child: const Text('分析风格'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final String title;
  final PickedPhoto? photo;
  final String emptyLabel;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _Slot({
    required this.title,
    required this.photo,
    required this.emptyLabel,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final picked = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (picked == null)
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(emptyLabel),
          )
        else
          SelectedPhotoCard(
            bytes: picked.bytes,
            sourceLabel: picked.sourceLabel,
            height: 180,
            onReplace: onPick,
            onRemove: onRemove,
          ),
      ],
    );
  }
}
