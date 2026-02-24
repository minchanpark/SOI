import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi/views/common_widget/about_voice_comment/voice_comment_widget.dart';
import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/user_controller.dart';

/// 음성 댓글을 녹음하는 UI 위젯
/// - 게시물에 대한 음성 댓글 녹음 기능을 제공합니다.
/// - VoiceCommentWidget을 사용하여 녹음, 저장, 삭제 등의 기능을 구현합니다.
///
/// Parameters:
/// - [post]: 현재 게시물 정보
/// - [voiceCommentActiveStates]: 게시물 ID별 음성 댓글 활성화 상태
/// - [postComments]: 게시물 ID별 댓글 목록
/// - [onVoiceCommentCompleted]: 음성 댓글 완료 콜백, 게시물 ID, 음성 파일 경로, 음성 파형 데이터, 댓글 ID를 인자로 받음
/// - [onVoiceCommentDeleted]: 음성 댓글 삭제 콜백, 게시물 ID를 인자로 받음
/// - [onProfileImageDragged]: 프로필 이미지 드래그 콜백, 게시물 ID와 드래그 위치를 인자로 받음
/// - [onSaveRequested]: 음성 댓글 저장 요청 콜백, 게시물 ID를 인자로 받음
/// - [onSaveCompleted]: 음성 댓글 저장 완료 콜백, 게시물 ID를 인자로 받음
/// - [pendingTextComments]: 게시물 ID별로 텍스트 댓글이 임시 저장된 상태를 나타내는 맵, true면 임시 저장된 댓글이 있음
class ApiVoiceCommentAudioWidget extends StatelessWidget {
  final Post post;
  final Map<int, bool> voiceCommentActiveStates;
  final Map<int, List<Comment>> postComments;
  final Function(int, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(int) onVoiceCommentDeleted;
  final Function(int, Offset) onProfileImageDragged;
  final Future<void> Function(int)? onSaveRequested;
  final Function(int)? onSaveCompleted;
  final Map<int, bool>? pendingTextComments;

  const ApiVoiceCommentAudioWidget({
    super.key,
    required this.post,
    required this.voiceCommentActiveStates,
    required this.postComments,
    required this.onVoiceCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    this.onSaveRequested,
    this.onSaveCompleted,
    this.pendingTextComments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('voice-widget-${post.id}'),
      alignment: Alignment.center,
      child: Consumer<UserController>(
        builder: (context, userController, child) {
          final currentUserProfileImage =
              userController.currentUser?.profileImageUrlKey;

          // 실시간 댓글 데이터로 저장 상태 확인
          final hasRealTimeComment = postComments[post.id]?.isNotEmpty ?? false;

          final shouldStartAsSaved =
              hasRealTimeComment && voiceCommentActiveStates[post.id] != true;

          final hasPendingTextComment = pendingTextComments?[post.id] ?? false;

          return VoiceCommentWidget(
            autoStart: !shouldStartAsSaved && !hasPendingTextComment,
            startAsSaved: shouldStartAsSaved,
            startInPlacingMode: hasPendingTextComment,
            profileImageUrl: currentUserProfileImage,
            enableMultipleComments: true,
            hasExistingComments: (postComments[post.id] ?? []).isNotEmpty,
            onSaveRequested: () async {
              if (onSaveRequested != null) {
                await onSaveRequested!(post.id);
              }
            },
            onSaveCompleted: () {
              onSaveCompleted?.call(post.id);
            },
            onRecordingCompleted: (audioPath, waveformData, duration) {
              onVoiceCommentCompleted(
                post.id,
                audioPath,
                waveformData,
                duration,
              );
            },
            onRecordingDeleted: () {
              onVoiceCommentDeleted(post.id);
            },
            onProfileImageDragged: (offset) {
              onProfileImageDragged(post.id, offset);
            },
          );
        },
      ),
    );
  }
}
