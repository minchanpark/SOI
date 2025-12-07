import 'package:flutter/material.dart';
import '../../common_widget/api_photo/api_photo_card_widget.dart';
import '../../common_widget/api_photo/pending_api_voice_comment.dart';
import '../../../api/models/comment.dart';
import '../manager/feed_data_manager.dart';

class FeedPageBuilder extends StatelessWidget {
  final List<FeedPostItem> posts;
  final bool hasMoreData;
  final bool isLoadingMore;
  final Map<int, List<Comment>> postComments;
  final Map<int, bool> voiceCommentActiveStates;
  final Map<int, bool> voiceCommentSavedStates;
  final Map<int, bool> pendingTextComments;
  final Map<int, PendingApiVoiceComment> pendingVoiceComments;
  final Function(FeedPostItem) onToggleAudio;
  final Function(int) onToggleVoiceComment;
  final Future<void> Function(int, String?, List<double>?, int?)
  onVoiceCommentCompleted;
  final Future<void> Function(int, String) onTextCommentCompleted;
  final Function(int) onVoiceCommentDeleted;
  final Function(int, Offset) onProfileImageDragged;
  final Future<void> Function(int) onSaveRequested;
  final Function(int) onSaveCompleted;
  final Future<void> Function(int, FeedPostItem) onDeletePost;
  final Function(int) onPageChanged;
  final VoidCallback onStopAllAudio;
  final String? currentUserNickname;

  const FeedPageBuilder({
    super.key,
    required this.posts,
    required this.hasMoreData,
    required this.isLoadingMore,
    required this.postComments,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    required this.pendingTextComments,
    required this.pendingVoiceComments,
    required this.onToggleAudio,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onTextCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    required this.onSaveRequested,
    required this.onSaveCompleted,
    required this.onDeletePost,
    required this.onPageChanged,
    required this.onStopAllAudio,
    this.currentUserNickname,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = posts.length + (hasMoreData ? 1 : 0);
    return PageView.builder(
      scrollDirection: Axis.vertical,
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
          postComments: postComments,
          voiceCommentActiveStates: voiceCommentActiveStates,
          voiceCommentSavedStates: voiceCommentSavedStates,
          pendingTextComments: pendingTextComments,
          pendingVoiceComments: pendingVoiceComments,
          onToggleAudio: (p) => onToggleAudio(feedItem),
          onToggleVoiceComment: onToggleVoiceComment,
          onVoiceCommentCompleted: onVoiceCommentCompleted,
          onTextCommentCompleted: onTextCommentCompleted,
          onVoiceCommentDeleted: onVoiceCommentDeleted,
          onProfileImageDragged: onProfileImageDragged,
          onSaveRequested: onSaveRequested,
          onSaveCompleted: onSaveCompleted,
          onDeletePressed: () => onDeletePost(index, feedItem),
        );
      },
    );
  }
}
