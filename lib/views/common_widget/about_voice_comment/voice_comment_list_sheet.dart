import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/models/comment_record_model.dart';
import '../../../api_firebase/controllers/emoji_reaction_controller.dart';
import '../../../api_firebase/controllers/comment_record_controller.dart';
import 'voice_comment_row_widget.dart';

/// 재사용 가능한 음성 댓글 리스트 Bottom Sheet
/// feed / archive 모두에서 사용
class VoiceCommentListSheet extends StatefulWidget {
  final String photoId;
  final String? categoryId;
  final String? commentIdFilter;

  // 선택된 댓글 ID (하이라이트용)
  final String? selectedCommentId;

  const VoiceCommentListSheet({
    super.key,
    required this.photoId,
    this.categoryId,
    this.commentIdFilter,

    // 선택된 댓글 ID 추가
    this.selectedCommentId,
  });

  @override
  State<VoiceCommentListSheet> createState() => _VoiceCommentListSheetState();
}

class _VoiceCommentListSheetState extends State<VoiceCommentListSheet> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 선택된 댓글로 자동 스크롤
  void _scrollToSelectedComment(
    List<CommentRecordModel> comments,
    List<Map<String, dynamic>> reactions,
  ) {
    if (widget.selectedCommentId == null) return;

    // 전체 아이템 리스트에서 선택된 댓글의 인덱스 찾기
    final hasCommentFilter = widget.commentIdFilter != null;
    final reactionCount = hasCommentFilter ? 0 : reactions.length;

    int? targetIndex;
    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == widget.selectedCommentId) {
        targetIndex = reactionCount + i;
        break;
      }
    }

    if (targetIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // 아이템 높이 추정 (각 댓글 행의 대략적인 높이 + separator)
          // 댓글 행 높이 추정
          const itemHeight = 80.0;
          const separatorHeight = 12.0;
          final scrollOffset = targetIndex! * (itemHeight + separatorHeight);

          // 선택된 댓글이 화면 중앙에 오도록 오프셋 조정
          final viewportHeight = _scrollController.position.viewportDimension;
          final centeredOffset =
              scrollOffset - (viewportHeight / 2) + (itemHeight / 2);

          // jumpTo를 사용하여 애니메이션 없이 즉시 중앙 위치로 이동
          _scrollController.jumpTo(
            centeredOffset.clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF323232),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.8),
          topRight: Radius.circular(24.8),
        ),
      ),
      padding: EdgeInsets.only(top: 18.h, bottom: 18.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          SizedBox(height: 3.h),
          Text(
            "공감",
            style: TextStyle(
              color: const Color(0xFFF8F8F8),
              fontSize: 18,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 19.h),
          // 통합 ListView: (리액션들 + 음성 댓글) 하나의 스크롤
          Consumer2<EmojiReactionController, CommentRecordController>(
            builder: (context, reactionController, recordController, _) {
              final hasCommentFilter = widget.commentIdFilter != null;

              // 1) 리액션 스트림 (optional)
              final reactionsStream =
                  (!hasCommentFilter && widget.categoryId != null)
                  ? reactionController.reactionsStream(
                      categoryId: widget.categoryId!,
                      photoId: widget.photoId,
                    )
                  : const Stream<List<Map<String, dynamic>>>.empty();

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: reactionsStream,
                builder: (context, reactSnap) {
                  final reactions = reactSnap.data ?? [];

                  // 2) 댓글 스트림 (중첩 StreamBuilder)
                  return StreamBuilder<List<CommentRecordModel>>(
                    stream: recordController.getCommentRecordsStream(
                      widget.photoId,
                    ),
                    builder: (context, commentSnap) {
                      final waiting =
                          reactSnap.connectionState ==
                              ConnectionState.waiting ||
                          commentSnap.connectionState ==
                              ConnectionState.waiting;
                      if (waiting) {
                        return SizedBox(
                          height: 120.h,
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (reactSnap.hasError || commentSnap.hasError) {
                        return SizedBox(
                          height: 120.h,
                          child: Center(
                            child: Text(
                              '불러오기 실패',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        );
                      }
                      final allComments = commentSnap.data ?? [];
                      final total =
                          (hasCommentFilter ? 0 : reactions.length) +
                          allComments.length;
                      if (total == 0) {
                        return SizedBox(
                          height: 120.h,
                          child: Center(
                            child: Text(
                              hasCommentFilter ? '댓글을 찾을 수 없습니다' : '댓글이 없습니다',
                              style: TextStyle(
                                color: const Color(0xFF9E9E9E),
                                fontSize: 16.sp,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }

                      // 자동 스크롤 실행
                      _scrollToSelectedComment(allComments, reactions);

                      return Flexible(
                        child: ListView.separated(
                          controller: _scrollController,
                          shrinkWrap: true,
                          itemCount: total,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            if (!hasCommentFilter && index < reactions.length) {
                              final reaction = reactions[index];
                              final reactionUserId =
                                  reaction['uid'] as String? ?? '';

                              // 리액션에 해당하는 댓글 찾기 (프로필 이미지용)
                              CommentRecordModel? commentForReaction;
                              if (reactionUserId.isNotEmpty) {
                                try {
                                  commentForReaction = allComments.firstWhere(
                                    (c) => c.recorderUser == reactionUserId,
                                  );
                                } catch (e) {
                                  commentForReaction = null;
                                }
                              }

                              // 리액션을 CommentRecordModel로 변환하여 VoiceCommentRow 사용
                              final fallbackProfile =
                                  reaction['profileImageUrl'] as String? ?? '';
                              final profileImageUrl =
                                  (commentForReaction
                                          ?.profileImageUrl
                                          .isNotEmpty ??
                                      false)
                                  ? commentForReaction!.profileImageUrl
                                  : fallbackProfile;

                              final createdAt = reaction['createdAt'];
                              final createdDate = createdAt is Timestamp
                                  ? createdAt.toDate()
                                  : DateTime.now();

                              final reactionComment = CommentRecordModel(
                                id: reaction['id'] as String? ?? '',
                                audioUrl: '',
                                photoId: widget.photoId,
                                recorderUser: reactionUserId,
                                createdAt: createdDate,
                                waveformData: [],
                                duration: 0,
                                profileImageUrl: profileImageUrl,
                                type: CommentType.emoji,
                                text: reaction['emoji'] as String? ?? '😊',
                              );

                              return VoiceCommentRow(
                                comment: reactionComment,
                                emoji: reaction['emoji'] as String? ?? '',
                                userName: reaction['id'] as String?,
                              );
                            }
                            final commentIndex =
                                index -
                                (hasCommentFilter ? 0 : reactions.length);
                            if (commentIndex >= 0 &&
                                commentIndex < allComments.length) {
                              final comment = allComments[commentIndex];
                              final isSelected =
                                  widget.selectedCommentId != null &&
                                  comment.id == widget.selectedCommentId;
                              return VoiceCommentRow(
                                comment: comment,

                                // 하이라이트 상태 전달
                                isHighlighted: isSelected,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
