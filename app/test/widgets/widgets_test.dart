import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/ai/analysis_result.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/state/providers.dart';
import 'package:ai_photo_stylist/widgets/param_slider.dart';
import 'package:ai_photo_stylist/widgets/suggestion_card.dart';

Widget wrap(Widget child) => ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

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
}

class _FixedSuggestionNotifier extends SuggestionNotifier {
  _FixedSuggestionNotifier(this._result);

  final AnalysisResult _result;

  @override
  AnalysisResult? build() => _result;
}
