// 단순 Dart 스크립트로 API 테스트
// 실행: dart run test/api_direct_test.dart

import 'package:soi/api/api_client.dart';
import 'package:soi/api/controller/api_comment_controller.dart';

void main() async {
  print('🚀 API 테스트 시작...');

  // API 클라이언트 초기화
  SoiApiClient.instance.initialize(basePath: 'https://newdawnsoi.site');

  final controller = ApiCommentController();

  // 테스트용 데이터
  const testPostId = 7;
  const testUserId = 11;
  const testContent = 'Dart 스크립트에서 작성한 댓글!';

  print('📝 텍스트 댓글 생성 테스트...');
  print('   - postId: $testPostId');
  print('   - userId: $testUserId');
  print('   - content: $testContent');

  final result = await controller.createTextComment(
    postId: testPostId,
    userId: testUserId,
    content: testContent,
    locationX: 5.5,
    locationY: 5.5,
  );

  print('📊 결과: ${result ? "성공 ✅" : "실패 ❌"}');
  if (controller.errorMessage != null) {
    print('❌ 에러 메시지: ${controller.errorMessage}');
  }

  print('🏁 테스트 완료!');
}
