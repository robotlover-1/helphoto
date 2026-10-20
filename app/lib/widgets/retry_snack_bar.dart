import 'package:flutter/material.dart';

/// 统一的失败提示：带「重试」操作，点击后重新执行 [onRetry]。
void showRetrySnackBar(BuildContext context, String message, VoidCallback onRetry) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: '重试', onPressed: onRetry),
      ),
    );
}
