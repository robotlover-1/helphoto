import '../models/edit_params.dart';

class AnalysisResult {
  final EditParams params;
  final String explanation;
  final String summary;

  const AnalysisResult({
    required this.params,
    required this.explanation,
    required this.summary,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawParams = json['params'];
    return AnalysisResult(
      params: rawParams is Map<String, dynamic>
          ? EditParams.fromJson(rawParams)
          : EditParams.zero,
      explanation: json['explanation'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
    );
  }
}
