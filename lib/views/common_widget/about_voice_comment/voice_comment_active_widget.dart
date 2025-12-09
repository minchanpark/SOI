import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/models/photo_data_model.dart';
import '../../../api_firebase/models/comment_record_model.dart';
import '../api_photo/voice_comment_widget.dart';

/// 음성 녹음이 활성화된 상태의 위젯
///
/// VoiceCommentWidget을 표시하고 음성 녹음 기능을 제공합니다.
class VoiceCommentActiveWidget extends StatelessWidget {
  final MediaDataModel photo;
  final Map<String, bool> voiceCommentActiveStates;
  final Map<String, String> userProfileImages;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Function(String, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(String) onVoiceCommentDeleted;
  final Function(String, Offset) onProfileImageDragged;
  final Future<void> Function(String)? onSaveRequested;
  final Function(String)? onSaveCompleted;
  final Map<String, bool>? pendingTextComments; // Pending 텍스트 댓글 상태

  const VoiceCommentActiveWidget({
    super.key,
    required this.photo,
    required this.voiceCommentActiveStates,
    required this.userProfileImages,
    required this.photoComments,
    required this.onVoiceCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    this.onSaveRequested,
    this.onSaveCompleted,
    this.pendingTextComments, // Pending 텍스트 댓글 상태 추가
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('voice-widget-${photo.id}'), // 고유 키 설정
      alignment: Alignment.center, // 내용을 중앙 정렬
      child: Consumer<AuthController>(
        builder: (context, authController, child) {
          final currentUserId = authController.currentUser?.uid;

          // Get profile image directly from AuthController (no cached photoId-based map)
          final currentUserProfileImage = currentUserId != null
              ? userProfileImages[currentUserId]
              : null;

          // 실시간 댓글 데이터로 저장 상태 확인 (우선순위)
          final hasRealTimeComment =
              photoComments[photo.id]?.any(
                (comment) => comment.recorderUser == currentUserId,
              ) ??
              false;

          // 위젯이 활성화된 상태에서는 댓글이 있어도 새로운 녹음 모드로 시작
          // (추가 댓글을 위한 로직)
          final shouldStartAsSaved =
              hasRealTimeComment && voiceCommentActiveStates[photo.id] != true;

          // Pending 텍스트 댓글이 있는 경우 자동 녹음 시작하지 않음
          final hasPendingTextComment = pendingTextComments?[photo.id] ?? false;

          debugPrint(
            '🔴 [ActiveWidget] photoId=${photo.id}, shouldStartAsSaved=$shouldStartAsSaved, hasPendingTextComment=$hasPendingTextComment',
          );
          debugPrint(
            '🔴 [ActiveWidget] pendingTextComments=$pendingTextComments',
          );

          // 다중 댓글 기능을 위해 항상 VoiceCommentWidget을 표시
          // 댓글이 없으면 VoiceCommentWidget 표시
          return VoiceCommentWidget(
            autoStart:
                !shouldStartAsSaved &&
                !hasPendingTextComment, // 텍스트 댓글이 pending 중이면 자동 시작 안 함
            startAsSaved: shouldStartAsSaved,
            startInPlacingMode:
                hasPendingTextComment, // 텍스트 댓글이 pending 중이면 placing 모드로 시작
            profileImageUrl: currentUserProfileImage, // 이미 fallback 처리된 값 사용
            enableMultipleComments: true, // 다중 댓글 활성화
            hasExistingComments: (photoComments[photo.id] ?? []).isNotEmpty,
            onSaveRequested: () async {
              // 파형 배치 확정 시 저장 요청
              if (onSaveRequested != null) {
                await onSaveRequested!(photo.id);
              }
            },
            onSaveCompleted: () {
              // 저장 완료 후 위젯 초기화
              onSaveCompleted?.call(photo.id);
            },
            onRecordingCompleted: (audioPath, waveformData, duration) {
              onVoiceCommentCompleted(
                photo.id,
                audioPath,
                waveformData,
                duration,
              );
            },
            onRecordingDeleted: () {
              onVoiceCommentDeleted(photo.id);
            },
            onProfileImageDragged: (offset) {
              // 프로필 이미지 드래그 처리
              onProfileImageDragged(photo.id, offset);
            },
          );
        },
      ),
    );
  }
}
