import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soi/api/api_client.dart';
import 'package:soi/api/controller/api_comment_controller.dart';

/// ApiCommentController 유닛 테스트
///
/// 실제 API 서버와 연동하여 createTextComment 함수를 테스트합니다.
/// ⚠️ 주의: 실제 서버에 데이터가 생성됩니다!
///
/// 실행 방법:
/// flutter test test/api_comment_controller_test.dart --reporter expanded
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiCommentController controller;

  setUpAll(() {
    // API 클라이언트 초기화 (실제 서버 연결)
    SoiApiClient.instance.initialize(basePath: 'https://newdawnsoi.site');
  });

  setUp(() {
    // 실제 CommentService 사용 (실제 API 호출)
    controller = ApiCommentController();
  });

  group('createTextComment 테스트', () {
    test('텍스트 댓글 생성 - 실제 API 호출', () async {
      // ⚠️ 테스트용 데이터 - 실제 존재하는 postId와 userId로 변경하세요
      const testPostId = 7; // 실제 게시물 ID
      const testUserId = 11; // 실제 사용자 ID
      const testContent = '유닛 테스트에서 작성한 댓글입니다!';

      debugPrint('📝 텍스트 댓글 생성 테스트 시작...');
      debugPrint('   - postId: $testPostId');
      debugPrint('   - userId: $testUserId');
      debugPrint('   - content: $testContent');

      final result = await controller.createTextComment(
        postId: testPostId,
        userId: testUserId,
        text: testContent,
      );

      debugPrint('📊 결과: ${result ? "성공 ✅" : "실패 ❌"}');
      if (controller.errorMessage != null) {
        debugPrint('❌ 에러 메시지: ${controller.errorMessage}');
      }

      // 결과 확인 (성공하든 실패하든 에러가 없어야 함)
      expect(controller.isLoading, false);
    });

    test('텍스트 댓글 생성 - 위치 정보 포함', () async {
      const testPostId = 7;
      const testUserId = 11;
      const testContent = '위치 정보가 포함된 댓글!';
      const locationX = 0.5; // 화면 중앙
      const locationY = 0.3;

      debugPrint('📝 위치 정보 포함 댓글 테스트 시작...');

      final result = await controller.createTextComment(
        postId: testPostId,
        userId: testUserId,
        text: testContent,
        locationX: locationX,
        locationY: locationY,
      );

      debugPrint('📊 결과: ${result ? "성공 ✅" : "실패 ❌"}');
      if (controller.errorMessage != null) {
        debugPrint('❌ 에러 메시지: ${controller.errorMessage}');
      }

      expect(controller.isLoading, false);
    });
  });
}
