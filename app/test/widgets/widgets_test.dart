import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ai_photo_stylist/ai/analysis_result.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/state/providers.dart';
import 'package:ai_photo_stylist/widgets/param_slider.dart';
import 'package:ai_photo_stylist/widgets/selected_photo_card.dart';
import 'package:ai_photo_stylist/widgets/suggestion_card.dart';

Widget wrap(Widget child) => ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

Uint8List _testPng() {
  final im = img.Image(width: 4, height: 4);
  img.fill(im, color: img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  testWidgets('ParamSlider 显示 label 与当前值', (tester) async {
    await tester.pumpWidget(wrap(ParamSlider(
      name: 'exposure',
      label: '曝光',
      value: 30,
      onChanged: (_) {},
    )));
    expect(find.text('曝光'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('SuggestionCard 空建议时不显示', (tester) async {
    await tester.pumpWidget(wrap(const SuggestionCard()));
    expect(find.textContaining('建议'), findsNothing);
  });

  testWidgets('SuggestionCard 显示 summary 与 explanation', (tester) async {
    final container = ProviderContainer(overrides: [
      suggestionProvider.overrideWith(() => _FixedSuggestionNotifier(
            const AnalysisResult(
              params: EditParams(),
              explanation: '提亮一点',
              summary: '清新',
            ),
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SuggestionCard())),
      ),
    );
    expect(find.text('清新'), findsOneWidget);
    expect(find.text('提亮一点'), findsOneWidget);
  });

  testWidgets('SelectedPhotoCard 显示蓝色勾与更换/移除', (tester) async {
    var replaced = false;
    var removed = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SelectedPhotoCard(
          bytes: _testPng(),
          sourceLabel: '相册',
          onReplace: () => replaced = true,
          onRemove: () => removed = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('相册'), findsWidgets);
    expect(find.text('更换'), findsOneWidget);
    expect(find.text('移除'), findsOneWidget);

    await tester.tap(find.text('更换'));
    await tester.tap(find.text('移除'));
    expect(replaced, isTrue);
    expect(removed, isTrue);
  });
}

class _FixedSuggestionNotifier extends SuggestionNotifier {
  _FixedSuggestionNotifier(this._result);

  final AnalysisResult _result;

  @override
  AnalysisResult? build() => _result;
}
