import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/audio_controller.dart';
import 'api_photo_display_widget.dart';
import 'api_user_info_widget.dart';
import 'api_voice_recording_widget.dart';
import 'api_voice_comment_list_sheet.dart';
import 'pending_api_voice_comment.dart';

/// API 기반 사진 카드 위젯
///
/// Firebase 버전의 PhotoCardWidgetCommon과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiPhotoCardWidget extends StatefulWidget {
  final Post post;
  final String categoryName;
  final int categoryId;
  final int index;
  final bool isOwner;
  final bool isArchive;
  final bool isCategory;

  // postId별 선택된 이모지 (부모가 관리)
  final String? selectedEmoji;
  final ValueChanged<String?>? onEmojiSelected; // 부모 캐시 갱신 콜백

  // 상태 관리 관련
  final Map<int, List<Comment>> postComments;
  final Map<int, bool> voiceCommentActiveStates;
  final Map<int, bool> voiceCommentSavedStates;
  final Map<int, bool>? pendingTextComments;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;

  // 콜백 함수들
  final Function(Post) onToggleAudio;
  final Function(int) onToggleVoiceComment;
  final Function(int, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(int, String) onTextCommentCompleted;
  final Function(int) onVoiceCommentDeleted;
  final Function(int, Offset) onProfileImageDragged;
  final Future<void> Function(int) onSaveRequested;
  final Function(int) onSaveCompleted;
  final VoidCallback onDeletePressed;
  final Future<void> Function(int postId)? onCommentsReloadRequested;

  const ApiPhotoCardWidget({
    super.key,
    required this.post,
    required this.categoryName,
    required this.categoryId,
    required this.index,
    required this.isOwner,
    this.isArchive = false,
    this.isCategory = false,
    this.selectedEmoji,
    this.onEmojiSelected,
    required this.postComments,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    this.pendingTextComments,
    this.pendingVoiceComments = const {},
    required this.onToggleAudio,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onTextCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    required this.onSaveRequested,
    required this.onSaveCompleted,
    required this.onDeletePressed,
    this.onCommentsReloadRequested,
  });

  @override
  State<ApiPhotoCardWidget> createState() => _ApiPhotoCardWidgetState();
}

class _ApiPhotoCardWidgetState extends State<ApiPhotoCardWidget> {
  bool _isTextFieldFocused = false;

  void _handleTextCommentCreated(String text) async {
    debugPrint(
      '[ApiPhotoCard] 텍스트 댓글 생성: postId=${widget.post.id}, text=$text',
    );
    await widget.onTextCommentCompleted(widget.post.id, text);
    widget.onToggleVoiceComment(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = _isTextFieldFocused;
    final bottomPadding = isKeyboardVisible
        ? 10.0
        : (widget.isCategory ? 55.0 : 10.0);

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!widget.isArchive) SizedBox(height: 90.h),

              // 사진 표시 위젯
              ApiPhotoDisplayWidget(
                key: ValueKey(widget.post.id),
                post: widget.post,
                categoryId: widget.categoryId,
                categoryName: widget.categoryName,
                isArchive: widget.isArchive,
                postComments: widget.postComments,
                onProfileImageDragged: widget.onProfileImageDragged,
                onToggleAudio: widget.onToggleAudio,
                pendingVoiceComments: widget.pendingVoiceComments,
                onCommentsReloadRequested: widget.onCommentsReloadRequested,
              ),
              SizedBox(height: 12.h),

              // 사용자 정보 위젯 (아이디와 날짜)
              ApiUserInfoWidget(
                post: widget.post,
                isCurrentUserPost: widget.isOwner,
                onDeletePressed: widget.onDeletePressed,
                onCommentsReloadRequested: widget.onCommentsReloadRequested,

                // 부모 상태 반영
                selectedEmoji: widget.selectedEmoji,

                // 부모 상태 갱신
                onEmojiSelected: widget.onEmojiSelected,

                onCommentPressed: () {
                  // 댓글 리스트 Bottom Sheet 표시
                  final comments = widget.postComments[widget.post.id] ?? [];
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return ChangeNotifierProvider(
                        create: (_) => AudioController(),
                        child: SizedBox(
                          height: 480.h,
                          child: ApiVoiceCommentListSheet(
                            postId: widget.post.id,
                            comments: comments,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 10.h),

              // 음성 녹음 위젯을 위한 공간 확보
              SizedBox(height: 90.h),
            ],
          ),
        ),

        // 음성 녹음 위젯을 Stack 위에 배치
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding,
          child: ApiVoiceRecordingWidget(
            post: widget.post,
            voiceCommentActiveStates: widget.voiceCommentActiveStates,
            voiceCommentSavedStates: widget.voiceCommentSavedStates,
            postComments: widget.postComments,
            onToggleVoiceComment: widget.onToggleVoiceComment,
            onVoiceCommentCompleted: widget.onVoiceCommentCompleted,
            onVoiceCommentDeleted: widget.onVoiceCommentDeleted,
            onProfileImageDragged: widget.onProfileImageDragged,
            onSaveRequested: widget.onSaveRequested,
            onSaveCompleted: widget.onSaveCompleted,
            pendingTextComments: widget.pendingTextComments,
            onTextFieldFocusChanged: (isFocused) {
              setState(() {
                _isTextFieldFocused = isFocused;
              });
            },
            onTextCommentCreated: _handleTextCommentCreated,
          ),
        ),
      ],
    );
  }
}

/// API 버전 Pending 음성 댓글 상태
