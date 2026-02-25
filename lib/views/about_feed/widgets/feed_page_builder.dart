import 'package:flutter/material.dart';
import '../../common_widget/api_photo/api_photo_card_widget.dart';
import '../../common_widget/about_comment_version_1/pending_api_voice_comment.dart';
import '../../../api/models/comment.dart';
import '../manager/feed_data_manager.dart';

class FeedPageBuilder extends StatelessWidget {
  final List<FeedPostItem> posts;
  final bool hasMoreData;
  final bool isLoadingMore;
  final Map<int, List<Comment>> postComments;
  final Map<int, String?> selectedEmojisByPostId; // postId별 선택된 이모지(부모가 관리)
  final Map<int, PendingApiCommentDraft> pendingCommentDrafts;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;
  final Function(FeedPostItem) onToggleAudio;
  final Future<void> Function(int, String) onTextCommentCompleted;
  final Future<void> Function(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  )
  onAudioCommentCompleted;
  final Future<void> Function(int postId, String localFilePath, bool isVideo)
  onMediaCommentCompleted;
  final Function(int, Offset) onProfileImageDragged;
  final void Function(int, double) onCommentSaveProgress;
  final void Function(int, Comment) onCommentSaveSuccess;
  final void Function(int, Object) onCommentSaveFailure;
  final Future<void> Function(int, FeedPostItem) onDeletePost;
  final Function(int) onPageChanged;
  final VoidCallback onStopAllAudio;
  final String? currentUserNickname;
  final Future<void> Function(int postId) onReloadComments; // 댓글 다시 불러오기 콜백 함수
  final void Function(int postId, String? emoji)
  onEmojiSelected; // 이모지 선택 시 캐시 갱신

  const FeedPageBuilder({
    super.key,
    required this.posts,
    required this.hasMoreData,
    required this.isLoadingMore,
    required this.postComments,
    required this.selectedEmojisByPostId,
    required this.pendingCommentDrafts,
    required this.pendingVoiceComments,
    required this.onToggleAudio,
    required this.onTextCommentCompleted,
    required this.onAudioCommentCompleted,
    required this.onMediaCommentCompleted,
    required this.onProfileImageDragged,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    required this.onDeletePost,
    required this.onPageChanged,
    required this.onStopAllAudio,
    this.currentUserNickname,
    required this.onReloadComments,
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = posts.length + (hasMoreData ? 1 : 0);
    return PageView.builder(
      scrollDirection: Axis.vertical,
      clipBehavior: Clip.none,
      itemCount: itemCount,
      onPageChanged: (index) {
        onPageChanged(index);
        onStopAllAudio();
      },
      itemBuilder: (context, index) {
        if (index >= posts.length) {
          return isLoadingMore
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }

        final feedItem = posts[index];
        final post = feedItem.post;
        final isOwner =
            currentUserNickname != null && currentUserNickname == post.nickName;

        return ApiPhotoCardWidget(
          post: post,
          categoryName: feedItem.categoryName,
          categoryId: feedItem.categoryId,
          index: index,
          isOwner: isOwner,
          selectedEmoji: selectedEmojisByPostId[post.id],
          onEmojiSelected: (emoji) => onEmojiSelected(post.id, emoji),
          postComments: postComments,
          pendingCommentDrafts: pendingCommentDrafts,
          pendingVoiceComments: pendingVoiceComments,
          onToggleAudio: (p) => onToggleAudio(feedItem),
          onTextCommentCompleted: onTextCommentCompleted,
          onAudioCommentCompleted: onAudioCommentCompleted,
          onMediaCommentCompleted: onMediaCommentCompleted,
          onProfileImageDragged: onProfileImageDragged,
          onCommentSaveProgress: onCommentSaveProgress,
          onCommentSaveSuccess: onCommentSaveSuccess,
          onCommentSaveFailure: onCommentSaveFailure,
          onDeletePressed: () => onDeletePost(index, feedItem),
          onCommentsReloadRequested: onReloadComments,
        );
      },
    );
  }
}
