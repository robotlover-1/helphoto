import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/analysis_result.dart';
import '../models/edit_params.dart';

class EditParamsNotifier extends Notifier<EditParams> {
  @override
  EditParams build() => EditParams.zero;

  void set(EditParams p) => state = p;

  void updateParam(String name, int value) {
    final v = value.clamp(EditParams.minValue, EditParams.maxValue);
    state = EditParams.fromJson({...state.toJson(), name: v});
  }

  void reset() => state = EditParams.zero;
}

final editParamsProvider =
    NotifierProvider<EditParamsNotifier, EditParams>(EditParamsNotifier.new);

class SuggestionNotifier extends Notifier<AnalysisResult?> {
  @override
  AnalysisResult? build() => null;

  void set(AnalysisResult r) => state = r;

  void clear() => state = null;
}

final suggestionProvider =
    NotifierProvider<SuggestionNotifier, AnalysisResult?>(SuggestionNotifier.new);

final analysisLoadingProvider = StateProvider<bool>((ref) => false);
