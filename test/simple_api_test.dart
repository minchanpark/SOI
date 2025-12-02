// 순수 Dart HTTP 테스트 - Flutter 의존성 없음
// 실행: dart run test/simple_api_test.dart

import 'dart:convert';
import 'dart:io';

void main() async {
  print('🚀 API 테스트 시작...');

  final client = HttpClient();

  try {
    final requestBody = {
      "userId": 11,
      "emojiId": 0,
      "postId": 7,
      "text": "Dart HTTP 테스트 댓글!",
      "audioKey": "",
      "waveformData": "",
      "duration": 0,
      "locationX": 5.5,
      "locationY": 5.5,
      "commentType": "TEXT",
    };

    print('📤 요청 데이터: ${jsonEncode(requestBody)}');

    final request = await client.postUrl(
      Uri.parse('https://newdawnsoi.site/comment/create'),
    );

    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(requestBody));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    print('📥 응답 상태: ${response.statusCode}');
    print('📥 응답 body: $responseBody');

    if (response.statusCode == 200) {
      print('✅ 성공!');
    } else {
      print('❌ 실패!');
    }
  } catch (e) {
    print('❌ 에러: $e');
  } finally {
    client.close();
  }

  print('🏁 테스트 완료!');
}
