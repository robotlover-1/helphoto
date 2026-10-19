import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/screens/edit_screen.dart';
import 'package:ai_photo_stylist/state/providers.dart';

void main() {
  testWidgets('EditScreen 渲染 8 个滑块与导出按钮', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EditScreen(image: null, colorShader: null),
        ),
      ),
    );
    // image 为空时显示占位，滑块仍渲染
    expect(find.text('曝光'), findsOneWidget);
    expect(find.text('阴影'), findsOneWidget);
    expect(find.text('导出'), findsOneWidget);
  });

  testWidgets('拖动滑块更新 editParamsProvider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: EditScreen(image: null, colorShader: null)),
      ),
    );
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(200, 0));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditScreen)),
    );
    expect(container.read(editParamsProvider).exposure, isNot(0));
  });
}
