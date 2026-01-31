import 'package:flutter/material.dart';
import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import 'api_voice_comment_active_widget.dart';
import 'api_voice_comment_text_widget.dart';

/// API 기반 음성 녹음 위젯
/// : 음성 댓글 입력 모드와 텍스트 댓글 입력 모드를 전환합니다.
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
            ? ApiVoiceCommentActiveWidget(
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
