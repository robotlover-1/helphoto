import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _initialized = false;
  String? _initError;

  static const _deniedCodes = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _initError = null);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initError = '未检测到可用相机');
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.max,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() => _initialized = true);
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = _deniedCodes.contains(e.code);
      setState(() => _initError = denied ? '相机权限被拒绝' : '无法打开相机');
      if (denied) await _showPermissionDialog();
    } catch (_) {
      if (mounted) setState(() => _initError = '无法打开相机');
    }
  }

  Future<void> _showPermissionDialog() async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要相机权限'),
        content: const Text('请在系统设置中允许本应用访问相机，然后重试。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('重试')),
        ],
      ),
    );
    if (retry == true && mounted) await _initCamera();
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final xfile = await controller.takePicture();
      final bytes = await xfile.readAsBytes();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('拍照失败')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('拍照')),
      body: _initialized && controller != null
          ? CameraPreview(controller)
          : Center(
              child: _initError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_initError!),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _initCamera, child: const Text('重试')),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initialized ? _takePicture : null,
        child: const Icon(Icons.camera),
      ),
    );
  }
}
