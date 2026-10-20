import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/screens/capture_screen.dart';

void main() {
  testWidgets('CaptureScreen 显示想法输入框与获取建议按钮', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CaptureScreen()),
      ),
    );
    expect(find.text('获取建议'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('CaptureScreen 显示拍照按钮', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CaptureScreen()),
      ),
    );
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('选择照片'), findsOneWidget);
  });

  testWidgets('点拍照弹出系统相机与应用内相机选项', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CaptureScreen()),
      ),
    );
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();

    expect(find.text('系统相机（推荐）'), findsOneWidget);
    expect(find.text('应用内相机'), findsOneWidget);
    expect(find.text('从相册选择'), findsOneWidget);
  });
}
