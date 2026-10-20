import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 主界面上展示已选照片的卡片：完整比例预览 + 蓝色勾选标识 + 更换/移除。
class SelectedPhotoCard extends StatelessWidget {
  static const blue = Color(0xFF1A73E8);

  final Uint8List bytes;
  final String sourceLabel;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;
  final double height;

  const SelectedPhotoCard({
    super.key,
    required this.bytes,
    required this.sourceLabel,
    this.onReplace,
    this.onRemove,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Image.memory(
              bytes,
              fit: BoxFit.contain,
              cacheWidth: 900,
              gaplessPlayback: true,
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      sourceLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 24, 8, 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sourceLabel,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: onReplace,
                      child: const Text(
                        '更换',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: onRemove,
                      child: const Text(
                        '移除',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
