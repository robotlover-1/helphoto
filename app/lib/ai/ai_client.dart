import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/edit_params.dart';
import 'analysis_result.dart';

class AiClientException implements Exception {
  final String message;
  AiClientException(this.message);
  @override
  String toString() => 'AiClientException: $message';
}

class AiClient {
  final http.Client client;
  final String baseUrl;

  AiClient({http.Client? client, required this.baseUrl})
      : client = client ?? http.Client();

  Future<AnalysisResult> analyze({
    required String mode,
    required Uint8List imageJpeg,
    Uint8List? referenceImageJpeg,
    String? intent,
    EditParams? currentParams,
    String? feedback,
  }) async {
    final uri = Uri.parse('$baseUrl/analyze');
    final body = <String, dynamic>{
      'mode': mode,
      'image': base64Encode(imageJpeg),
      'imageMediaType': 'image/jpeg',
    };
    if (referenceImageJpeg != null) {
      body['referenceImage'] = base64Encode(referenceImageJpeg);
    }
    if (intent != null) body['intent'] = intent;
    if (currentParams != null) body['currentParams'] = currentParams.toJson();
    if (feedback != null) body['feedback'] = feedback;

    try {
      final resp = await client.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        throw AiClientException(decoded['error']?.toString() ?? 'status ${resp.statusCode}');
      }
      return AnalysisResult.fromJson(decoded);
    } on AiClientException {
      rethrow;
    } catch (e) {
      throw AiClientException(e.toString());
    }
  }
}
