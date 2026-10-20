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

    final http.Response resp;
    try {
      resp = await client.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw AiClientException('网络连接失败，请检查网络后重试');
    }

    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      decoded = null;
    }

    if (resp.statusCode != 200) {
      throw AiClientException(
        friendlyMessage(resp.statusCode, decoded?['error']?.toString()),
      );
    }
    if (decoded == null) {
      throw AiClientException('服务返回格式异常，请重试');
    }
    return AnalysisResult.fromJson(decoded);
  }

  /// 把 HTTP 状态码转成面向用户的提示。
  static String friendlyMessage(int status, [String? serverError]) {
    switch (status) {
      case 400:
        return '请求无效，请重试';
      case 401:
      case 403:
        return '服务密钥无效或额度不足，请检查后端配置';
      case 429:
        return '请求过于频繁或额度不足，请稍后重试';
      case 502:
      case 503:
      case 504:
        return '分析服务暂时不可用，请稍后重试';
      default:
        return serverError ?? '服务错误（HTTP $status），请重试';
    }
  }
}
