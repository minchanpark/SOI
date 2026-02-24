import 'package:flutter/material.dart';
import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import 'api_voice_comment_audio_widget.dart';
import 'api_voice_comment_text_widget.dart';

/// 음성 댓글과 텍스트 댓글 입력 UI를 통합한 위젯
/// - 음성 댓글 토글 버튼과 텍스트 입력 필드, 전송 버튼을 포함
/// - 텍스트 입력 시 댓글이 임시 저장되고, 음성 댓글 버튼 클릭 시 음성 댓글 UI로 전환
/// - 댓글 입력 필드에 포커스가 생기거나 사라질 때 콜백을 통해 부모 위젯에 알림
/// - 텍스트 댓글이 생성되면 콜백을 통해 부모 위젯에 전달
/// UI 디자인:
/// - 배경: #161616, 테두리: #66D99D, 테두리 두께: 1.2, 모서리 반경: 21.5
/// - 음성 댓글 버튼: 마이크 아이콘, 크기 36x36, 왼쪽 여백 11
/// - 텍스트 입력 필드: 힌트 텍스트 "댓글 추가 ....", 폰트 크기 16, 폰트 패밀리 'Pretendard', 폰트 두께 200, 글자 간격 -1.14, 텍스트 색상 흰색
/// - 전송 버튼: 보내기 아이콘, 크기 17x17, 오른쪽 여백 11, 텍스트 입력 중에는 로딩 인디케이터로 대체
///
/// Parameters:
/// - [post]: 현재 게시물 정보
/// - [voiceCommentActiveStates]: 게시물 ID별 음성 댓글 활성화 상태
/// - [voiceCommentSavedStates]: 게시물 ID별 음성 댓글 저장 상태
/// - [postComments]: 게시물 ID별 댓글 목록
/// - [onToggleVoiceComment]: 음성 댓글 토글 콜백, 게시물 ID를 인자로 받음
/// - [onVoiceCommentCompleted]: 음성 댓글 완료 콜백, 게시물 ID, 음성 파일 경로, 음성 파형 데이터, 댓글 ID를 인자로 받음
/// - [onVoiceCommentDeleted]: 음성 댓글 삭제 콜백, 게시물 ID를 인자로 받음
/// - [onProfileImageDragged]: 프로필 이미지 드래그 콜백, 게시물 ID와 드래그 위치를 인자로 받음
/// - [onSaveRequested]: 음성 댓글 저장 요청 콜백, 게시물 ID를 인자로 받음
/// - [onSaveCompleted]: 음성 댓글 저장 완료 콜백, 게시물 ID를 인자로 받음
/// - [onTextFieldFocusChanged]: 텍스트 필드 포커스 변경 콜백, 포커스 상태를 인자로 받음
/// - [onTextCommentCreated]: 텍스트 댓글 생성 콜백, 생성된 댓글 텍스트를 인자로 받음
/// - [pendingTextComments]: 게시물 ID별로 텍스트 댓글이 임시 저장된 상태를 나타내는 맵, true면 임시 저장된 댓글이 있음
class ApiVoiceRecordingWidget extends StatelessWidget {
  final Post post;
  final Map<int, bool> voiceCommentActiveStates;
  final Map<int, bool> voiceCommentSavedStates;
  final Map<int, List<Comment>> postComments;
  final Function(int) onToggleVoiceComment;
  final Function(int, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(int) onVoiceCommentDeleted;
  final Function(int, Offset) onProfileImageDragged;
  final Future<void> Function(int)? onSaveRequested;
  final Function(int)? onSaveCompleted;
  final Function(bool)? onTextFieldFocusChanged;
  final Function(String)? onTextCommentCreated;
  final Map<int, bool>? pendingTextComments;

  const ApiVoiceRecordingWidget({
    super.key,
    required this.post,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    required this.postComments,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    this.onSaveRequested,
    this.onSaveCompleted,
    this.onTextFieldFocusChanged,
    this.onTextCommentCreated,
    this.pendingTextComments,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: voiceCommentActiveStates[post.id] == true
            // 음성 댓글 입력 모드
            ? ApiVoiceCommentAudioWidget(
                post: post,
                voiceCommentActiveStates: voiceCommentActiveStates,
                postComments: postComments,
                onVoiceCommentCompleted: onVoiceCommentCompleted,
                onVoiceCommentDeleted: onVoiceCommentDeleted,
                onProfileImageDragged: onProfileImageDragged,
                onSaveRequested: onSaveRequested,
                onSaveCompleted: onSaveCompleted,
                pendingTextComments: pendingTextComments,
              )
            // 텍스트 댓글 입력 모드
            : ApiVoiceCommentTextWidget(
                postId: post.id,
                onToggleVoiceComment: onToggleVoiceComment,
                onFocusChanged: onTextFieldFocusChanged,
                onTextCommentCreated: onTextCommentCreated,
              ),
      ),
    );
  }
}
