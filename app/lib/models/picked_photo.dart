import 'dart:typed_data';

/// 一张已经选好/拍好的照片。
class PickedPhoto {
  /// 原始字节（相册为 2048px 缩略 JPEG，相机为拍摄原图）。
  final Uint8List bytes;

  /// 来源标签，例如「相册」「系统相机」「应用内相机」。
  final String sourceLabel;

  const PickedPhoto({required this.bytes, required this.sourceLabel});
}
