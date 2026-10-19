import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_photo_stylist/ai/ai_client.dart';
import 'package:ai_photo_stylist/ai/analysis_result.dart';
import 'package:ai_photo_stylist/models/edit_params.dart';

void main() {
  test('analyze 解析响应为 AnalysisResult', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/analyze');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['mode'], 'intent');
      expect(body['intent'], '日系');
      return http.Response(
        jsonEncode({
          'params': {'exposure': 12, 'temperature': -18},
          'explanation': '提亮偏冷',
          'summary': '清新',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = AiClient(client: mock, baseUrl: 'http://localhost:8787');
    final r = await client.analyze(
      mode: 'intent',
      imageJpeg: Uint8List.fromList([1, 2, 3]),
      intent: '日系',
    );

    expect(r.params.exposure, 12);
    expect(r.params.temperature, -18);
    expect(r.params.contrast, 0);
    expect(r.summary, '清新');
  });

  test('analyze 网络错误抛 AiClientException', () async {
    final mock = MockClient((_) async => throw Exception('boom'));
    final client = AiClient(client: mock, baseUrl: 'http://x');
    expect(
      () => client.analyze(mode: 'intent', imageJpeg: Uint8List(0)),
      throwsA(isA<AiClientException>()),
    );
  });
}
