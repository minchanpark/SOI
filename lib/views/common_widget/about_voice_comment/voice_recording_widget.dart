import 'package:flutter/material.dart';
import '../../../api_firebase/models/photo_data_model.dart';
import '../../../api_firebase/models/comment_record_model.dart';
import 'voice_comment_active_widget.dart';
import 'voice_comment_text_widget.dart';

/// 음성 녹음 위젯
///
/// 피드에서 음성 댓글 녹음과 관련된 모든 기능을 담당합니다.
/// 음성 댓글 버튼, VoiceCommentWidget, 저장된 프로필 이미지 표시 등을 포함합니다.
class VoiceRecordingWidget extends StatelessWidget {
  final MediaDataModel photo;
  final Map<String, bool> voiceCommentActiveStates;
  final Map<String, bool> voiceCommentSavedStates;
  final Map<String, String> userProfileImages;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Function(String) onToggleVoiceComment;
  final Function(String, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(String) onVoiceCommentDeleted;
  final Function(String, Offset) onProfileImageDragged;
  final Future<void> Function(String)? onSaveRequested; // 프로필 배치 확정 시 저장
  final Function(String)? onSaveCompleted; // 저장 완료 후 초기화 콜백
  final Function(bool)? onTextFieldFocusChanged; // 텍스트 필드 포커스 변경 콜백
  final Function(String)? onTextCommentCreated; // 텍스트 댓글 생성 콜백
  final Map<String, bool>? pendingTextComments; // Pending 텍스트 댓글 상태

  const VoiceRecordingWidget({
    super.key,
    required this.photo,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    required this.userProfileImages,
    required this.photoComments,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    this.onSaveRequested,
    this.onSaveCompleted,
    this.onTextFieldFocusChanged,
    this.onTextCommentCreated, // 텍스트 댓글 생성 콜백 추가
    this.pendingTextComments, // Pending 텍스트 댓글 상태 추가
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
        child: voiceCommentActiveStates[photo.id] == true
            ? VoiceCommentActiveWidget(
                photo: photo,
                voiceCommentActiveStates: voiceCommentActiveStates,
                userProfileImages: userProfileImages,
                photoComments: photoComments,
                onVoiceCommentCompleted: onVoiceCommentCompleted,
                onVoiceCommentDeleted: onVoiceCommentDeleted,
                onProfileImageDragged: onProfileImageDragged,
                onSaveRequested: onSaveRequested,
                onSaveCompleted: onSaveCompleted,
                pendingTextComments:
                    pendingTextComments, // Pending 텍스트 댓글 상태 전달
              )
            : VoiceCommentTextWidget(
                photoId: photo.id,
                onToggleVoiceComment: onToggleVoiceComment,
                onFocusChanged: onTextFieldFocusChanged,
                onTextCommentCreated: onTextCommentCreated, // 텍스트 댓글 생성 콜백 전달
              ),
      ),
    );
  }
}
