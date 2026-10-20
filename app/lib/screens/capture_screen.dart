import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../ai/ai_client.dart';
import '../engine/color_shader.dart';
import '../engine/image_codec.dart';
import '../models/picked_photo.dart';
import '../state/providers.dart';
import '../widgets/retry_snack_bar.dart';
import '../widgets/selected_photo_card.dart';
import 'camera_screen.dart';
import 'edit_screen.dart';
import 'photo_gallery_screen.dart';
import 'style_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _picker = ImagePicker();
  final _intentController = TextEditingController();
  PickedPhoto? _photo;

  @override
  void dispose() {
    _intentController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final bytes = await PhotoGalleryScreen.pick(context);
      if (bytes == null || bytes.isEmpty || !mounted) return;
      setState(() {
        _photo = PickedPhoto(bytes: bytes, sourceLabel: '相册');
      });
    } catch (_) {
      if (mounted) {
        showRetrySnackBar(context, '无法读取相册，请检查照片权限', _pickFromGallery);
      }
    }
  }

  Future<void> _showPhotoOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('系统相机（推荐）'),
              subtitle: const Text('可使用人像、夜景、专业等手机相机模式'),
              onTap: () => Navigator.pop(ctx, 'system'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('应用内相机'),
              subtitle: const Text('在应用内直接取景拍摄'),
              onTap: () => Navigator.pop(ctx, 'inapp'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'gallery':
        await _pickFromGallery();
        break;
      case 'system':
        await _captureSystem();
        break;
      case 'inapp':
        await _captureInApp();
        break;
    }
  }

  Future<void> _captureSystem() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || !mounted) return;
      setState(() {
        _photo = PickedPhoto(bytes: bytes, sourceLabel: '系统相机');
      });
    } on PlatformException {
      if (mounted) {
        showRetrySnackBar(context, '无法打开系统相机，请检查相机权限', _captureSystem);
      }
    }
  }

  Future<void> _captureInApp() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (bytes == null || bytes.isEmpty || !mounted) return;
    setState(() {
      _photo = PickedPhoto(bytes: bytes, sourceLabel: '应用内相机');
    });
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null) return;

    ref.read(analysisLoadingProvider.notifier).state = true;
    try {
      final prepared = await prepareImage(photo.bytes);
      final client = AiClient(
        baseUrl: const String.fromEnvironment(
          'AI_BASE_URL',
          defaultValue: 'http://10.0.2.2:8787',
        ),
      );
      final result = await client.analyze(
        mode: 'intent',
        imageJpeg: prepared.analysisJpeg,
        intent: _intentController.text,
      );
      if (!mounted) return;
      ref.read(suggestionProvider.notifier).set(result);
      ref.read(editParamsProvider.notifier).set(result.params);

      final program = await loadColorShader();
      final shader = ColorShader(program);
      final image = await bytesToUiImage(prepared.previewJpeg);
      if (!mounted) {
        image.dispose();
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EditScreen(
          image: image,
          colorShader: shader,
          imageJpeg: prepared.analysisJpeg,
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
    final photo = _photo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 摄影指导'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StyleScreen()),
            ),
            child: const Text('风格迁移'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (photo == null)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showPhotoOptions,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('拍照'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('选择照片'),
                      ),
                    ),
                  ],
                )
              else
                SelectedPhotoCard(
                  bytes: photo.bytes,
                  sourceLabel: photo.sourceLabel,
                  height: (MediaQuery.sizeOf(context).height * 0.34)
                      .clamp(140.0, 280.0),
                  onReplace: _showPhotoOptions,
                  onRemove: () => setState(() => _photo = null),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _intentController,
                decoration: const InputDecoration(
                  labelText: '想要什么感觉？',
                  hintText: '例如：日系清新、复古胶片、电影感',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: photo == null ? null : _analyze,
                  child: const Text('获取建议'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
