import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/user_controller.dart';
import '../about_voice_comment/voice_comment_widget.dart';

/// API 기반 음성 녹음 활성화 상태 위젯
///
/// Firebase 버전의 VoiceCommentActiveWidget과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiVoiceCommentActiveWidget extends StatelessWidget {
  final Post post;
  final Map<int, bool> voiceCommentActiveStates;
  final Map<int, List<Comment>> postComments;
  final Function(int, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(int) onVoiceCommentDeleted;
  final Function(int, Offset) onProfileImageDragged;
  final Future<void> Function(int)? onSaveRequested;
  final Function(int)? onSaveCompleted;
  final Map<int, bool>? pendingTextComments;

  const ApiVoiceCommentActiveWidget({
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

          debugPrint(
            '🔴 [ApiActiveWidget] postId=${post.id}, shouldStartAsSaved=$shouldStartAsSaved, hasPendingTextComment=$hasPendingTextComment',
          );

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
