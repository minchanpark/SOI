import 'comment.dart';

/// 댓글 생성 요청에 대한 결과 모델.
///
/// - [success]가 true이면 서버 저장이 성공했음을 의미합니다.
/// - [comment]는 서버가 응답으로 내려준 댓글 데이터이며,
///   null일 경우에는 전체 목록을 다시 조회해야 합니다.
class CommentCreationResult {
  final bool success;
  final Comment? comment;

  const CommentCreationResult({
    required this.success,
    this.comment,
  });

  /// 실패 결과를 빠르게 생성할 수 있는 헬퍼.
  const CommentCreationResult.failure() : this(success: false);
}
