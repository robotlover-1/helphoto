import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// 应用内相册网格：点选照片出现蓝色勾，完成时返回 2048px 的 JPEG 字节。
class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  static Future<Uint8List?> pick(BuildContext context) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const PhotoGalleryScreen()),
    );
  }

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  static const _pageSize = 60;

  final _scrollController = ScrollController();
  final _thumbFutures = <String, Future<Uint8List?>>{};
  final _assets = <AssetEntity>[];

  AssetPathEntity? _album;
  AssetEntity? _selected;
  PermissionState? _permission;
  bool _loading = true;
  bool _loadingMore = false;
  bool _confirming = false;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _permission = null;
    });

    final permission = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    if (!permission.hasAccess) {
      setState(() {
        _permission = permission;
        _loading = false;
      });
      return;
    }

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (!mounted) return;
    if (paths.isEmpty) {
      setState(() {
        _permission = permission;
        _loading = false;
        _hasMore = false;
      });
      return;
    }

    _album = paths.first;
    _assets.clear();
    _page = 0;
    _hasMore = true;
    setState(() => _loading = false);
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final page = await album.getAssetListPaged(
        page: _page,
        size: _pageSize,
        type: RequestType.image,
      );
      if (!mounted) return;
      setState(() {
        _assets.addAll(page);
        _page += 1;
        _hasMore = page.length == _pageSize;
      });
    } finally {
      _loadingMore = false;
    }
  }

  Future<Uint8List?> _loadPickedBytes(AssetEntity asset) async {
    // 2048px 缩略图由系统解码，HEIC 也能输出 JPEG，且避免整张原图占用内存。
    final bytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize(2048, 2048),
      quality: 92,
    );
    if (bytes != null && bytes.isNotEmpty) return bytes;
    return asset.originBytes;
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null || _confirming) return;
    setState(() => _confirming = true);
    try {
      final bytes = await _loadPickedBytes(selected);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('读取照片失败，请换一张试试')),
        );
        return;
      }
      Navigator.of(context).pop(Uint8List.fromList(bytes));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('读取照片失败，请换一张试试')),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<Uint8List?> _thumb(AssetEntity asset) {
    return _thumbFutures.putIfAbsent(
      asset.id,
      () => asset.thumbnailDataWithSize(const ThumbnailSize.square(300)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permission = _permission;
    final denied = permission != null && !permission.hasAccess;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择照片'),
        actions: [
          if (_confirming)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _selected == null ? null : _confirm,
              child: const Text('完成'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : denied
              ? _PermissionView(onRetry: _init)
              : _buildGrid(permission),
    );
  }

  Widget _buildGrid(PermissionState? permission) {
    if (_assets.isEmpty) {
      return const Center(child: Text('相册里还没有照片'));
    }
    return Column(
      children: [
        if (permission != null && permission.isLimited)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text('当前只能访问部分照片，可在系统设置中允许访问全部照片'),
          ),
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _assets.length,
            itemBuilder: (context, index) {
              final asset = _assets[index];
              final selected = _selected?.id == asset.id;
              return _ThumbnailTile(
                future: _thumb(asset),
                selected: selected,
                onTap: () {
                  setState(() => _selected = selected ? null : asset);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  final Future<Uint8List?> future;
  final bool selected;
  final VoidCallback onTap;

  const _ThumbnailTile({
    required this.future,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: future,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) {
                return Container(color: Colors.black12);
              }
              return Image.memory(
                data,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              );
            },
          ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1A73E8), width: 3),
                color: const Color(0xFF1A73E8).withValues(alpha: 0.18),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFF1A73E8)
                    : Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  final VoidCallback onRetry;

  const _PermissionView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 56),
            const SizedBox(height: 16),
            const Text('需要相册权限才能选择照片', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              '请在系统设置中允许本应用访问照片，然后返回重试。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: PhotoManager.openSetting,
              child: const Text('去设置'),
            ),
            TextButton(onPressed: onRetry, child: const Text('重新检测')),
          ],
        ),
      ),
    );
  }
}
