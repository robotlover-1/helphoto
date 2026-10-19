import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_photo_stylist/ai/analysis_result.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';
import 'package:ai_photo_stylist/state/providers.dart';

void main() {
  test('updateParam 更新单参数且保留其余', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editParamsProvider.notifier).updateParam('exposure', 40);
    expect(container.read(editParamsProvider).exposure, 40);
    expect(container.read(editParamsProvider).contrast, 0);
  });

  test('set 整体替换参数', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editParamsProvider.notifier).set(const EditParams(contrast: 9));
    expect(container.read(editParamsProvider).contrast, 9);
    expect(container.read(editParamsProvider).exposure, 0);
  });

  test('suggestion 初始为 null，set 后保留', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(suggestionProvider), isNull);
    container.read(suggestionProvider.notifier).set(
          const AnalysisResult(
            params: EditParams(exposure: 5),
            explanation: 'x',
            summary: 'y',
          ),
        );
    expect(container.read(suggestionProvider)!.summary, 'y');
  });
}
