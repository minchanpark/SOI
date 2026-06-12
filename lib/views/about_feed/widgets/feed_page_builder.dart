import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';

import '../../common_widget/comment/comment_list_bottom_sheet.dart';
import '../../common_widget/photo/photo_card_widget.dart';
import '../../common_widget/photo/user_info_widget.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/models/comment.dart';
import '../../../features/tagging_soi/tagging_soi.dart';
import '../manager/feed_data_manager.dart';

/// 피드 화면 레이아웃 위젯.
///
/// 사진/영상 부분만 위아래로 스크롤되고,
/// 작성자 정보와 댓글 입력창은 화면에 고정되어 있습니다.
class FeedPageBuilder extends StatefulWidget {
  final List<FeedPostItem> posts;
  final bool hasMoreData;
  final bool isLoadingMore;
  final Map<TagScopeId, String?> selectedEmojisByScopeId;
  final Map<TagScopeId, TagDraft> pendingCommentDrafts;
  final Map<TagScopeId, TagPendingMarker> pendingVoiceComments;
  final SoiTaggingController taggingController;
  final TagMutationPort saveDelegate;
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
  final void Function(int, TagComment) onCommentSaveSuccess;
  final void Function(int, Object) onCommentSaveFailure;
  final Future<void> Function(int, FeedPostItem) onDeletePost;
  final Function(int) onPageChanged;
  final VoidCallback onStopAllAudio;
  final String? currentUserNickname;
  final Future<void> Function(int postId) onReloadComments;
  final Future<List<Comment>> Function(int postId) onLoadFullComments;
  final void Function(int postId, String? emoji) onEmojiSelected;

  final PageController? pageController;

  const FeedPageBuilder({
    super.key,
    required this.posts,
    required this.hasMoreData,
    required this.isLoadingMore,
    required this.selectedEmojisByScopeId,
    required this.pendingCommentDrafts,
    required this.pendingVoiceComments,
    required this.taggingController,
    required this.saveDelegate,
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
    required this.onLoadFullComments,
    required this.onEmojiSelected,
    this.pageController,
  });

  @override
  State<FeedPageBuilder> createState() => _FeedPageBuilderState();
}

/// FeedPageBuilder의 상태 관리 클래스.
/// 지금 보이는 게시물 번호를 기억하고,
/// 페이지가 바뀔 때 작성자 정보와 댓글 입력창을 새 게시물에 맞게 바꿔줍니다.
class _FeedPageBuilderState extends State<FeedPageBuilder> {
  /// 지금 화면에 보이는 게시물의 순서 번호.
  int _currentIndex = 0;
  bool _isTextFieldFocused = false;

  /// 피드 카드가 다루는 post 식별자를 tagging scope 계약으로 맞춥니다.
  TagScopeId _postScopeId(int postId) => SoiTaggingIds.postScopeId(postId);

  /// 게시물이 한 장뿐인 경우에는 PageView 대신 refresh 전용 scroll host를 사용해 Android pull-to-refresh를 안정화합니다.
  bool get _usesSinglePostRefreshScroll =>
      widget.posts.length == 1 && !widget.hasMoreData;

  /// 피드 시트에서 바뀐 full thread를 controller cache 한 곳에 되돌립니다.
  void _replaceCommentCaches(int postId, List<Comment> updatedComments) {
    widget.taggingController.replaceCommentsCache(
      _postScopeId(postId),
      SoiTagCommentMapper.fromComments(
        updatedComments,
        scopeId: _postScopeId(postId),
      ),
    );
  }

  /// 지금 보이는 게시물을 반환합니다. 목록이 비어 있거나 범위를 벗어나면 null을 반환합니다.
  /// 부모 위젯에서 전달된 게시물 목록과 현재 인덱스를 기준으로 현재 게시물을 계산합니다.
  /// - widget.posts[_currentIndex]가 유효한 범위에 있으면 해당 게시물을 반환하고, 그렇지 않으면 null을 반환합니다.
  FeedPostItem? get _currentPost =>
      widget.posts.isNotEmpty && _currentIndex < widget.posts.length
      ? widget.posts[_currentIndex]
      : null;

  /// 댓글 시트는 full cache가 없을 때 원댓글 미리보기를 먼저 사용하고, 마지막 fallback으로 태그 캐시를 사용합니다.
  List<Comment> _initialSheetCommentsForPost(int postId) {
    final commentController = context.read<CommentController>();
    final fullComments =
        commentController.peekCommentsCache(postId: postId) ??
        const <Comment>[];
    if (fullComments.isNotEmpty) {
      return fullComments;
    }

    final parentComments =
        commentController.peekParentCommentsCache(postId: postId) ??
        const <Comment>[];
    if (parentComments.isNotEmpty) {
      return parentComments;
    }

    return commentController.peekTagCommentsCache(postId: postId) ??
        const <Comment>[];
  }

  /// 작성 중인 댓글의 종류를 문자열로 반환합니다. Mixpanel event 기록에 사용됩니다.
  /// 작성 중인 댓글이
  /// 없으면 'unknown',
  /// 있으면 'text' / 'audio' / 'image' / 'video' 중 하나를 반환합니다.
  ///
  /// parameters:
  /// - [draft]: 작성 중인 댓글의 임시 데이터. null이면 댓글 작성이 없는 것으로 간주합니다.
  ///
  /// returns:
  /// - [String]
  ///   - 'text', 'audio', 'image', 'video' 중 하나. 작성 중인 댓글의 종류에 따라 결정됩니다.
  ///   - 'unknown' 작성 중인 댓글이 없거나, 종류를 판단할 수 없는 경우 반환됩니다.
  String _resolveTagContentType(TagDraft? draft) {
    if (draft == null) return 'unknown';
    if (draft.isTextComment) return 'text';
    if (draft.isAudioComment) return 'audio';
    if (draft.isImageComment) return 'image';
    if (draft.isVideoComment) return 'video';
    return 'unknown';
  }

  /// 댓글 태그가 사진에 저장됐을 때,  Mixpanel event를 전송합니다.
  /// 댓글 종류, 기존 태그 수, 게시물/카테고리 ID 등의 정보를 함께 보냅니다.
  Future<void> _trackCommentTagSaved({
    required int postId,
    required int categoryId,
    required String tagContentType,
    required int existingTagCountBefore,
    required TagComment comment,
  }) async {
    await SoiTaggingAnalytics.trackCommentTagSaved(
      context,
      postId: postId,
      categoryId: categoryId,
      surface: 'feed_home',
      tagContentType: tagContentType,
      existingTagCountBefore: existingTagCountBefore,
      comment: comment,
    );
  }

  Future<bool> _requestCameraDraft(TagScopeId scopeId) {
    final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
    return SoiTaggingComposerActions.requestCameraDraft(
      context: context,
      onSelected: (localFilePath, isVideo) async {
        await widget.onMediaCommentCompleted(postId, localFilePath, isVideo);
      },
    );
  }

  Future<bool> _requestAudioDraft(TagScopeId scopeId) {
    final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
    return SoiTaggingComposerActions.requestAudioDraft(
      context: context,
      onSelected: (audioPath, waveformData, durationMs) async {
        await widget.onAudioCommentCompleted(
          postId,
          audioPath,
          waveformData,
          durationMs,
        );
      },
    );
  }

  /// 게시물 수에 따라 PageView 또는 단일 카드 레이아웃을 선택해 refresh 제스처와 페이지 스와이프를 함께 보장합니다.
  Widget _buildMediaViewport(int itemCount) {
    if (_usesSinglePostRefreshScroll) {
      final feedItem = widget.posts.first;
      return _buildFeedPhotoCard(feedItem, 0);
    }

    return PageView.builder(
      controller: widget.pageController,
      scrollDirection: Axis.vertical, // 상하로 스크롤
      clipBehavior: Clip.hardEdge, // 페이지가 화면 밖으로 넘어가지 않도록 클리핑
      itemCount: itemCount, // 게시물 수 + 로딩 인디케이터(있으면)
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
        widget.onPageChanged(index);
        widget.onStopAllAudio();
      },
      physics: const PageScrollPhysics(),
      itemBuilder: (context, index) {
        if (index >= widget.posts.length) {
          return widget.isLoadingMore
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }
        return _buildFeedPhotoCard(widget.posts[index], index);
      },
    );
  }

  /// 피드 카드 한 장의 공통 조립을 분리해 단일 카드/페이지뷰 모드가 같은 UI를 공유하게 합니다.
  Widget _buildFeedPhotoCard(FeedPostItem feedItem, int index) {
    return ApiPhotoCardWidget(
      key: ValueKey(feedItem.post.id),
      post: feedItem.post,
      categoryName: feedItem.categoryName,
      categoryId: feedItem.categoryId,
      index: index,
      isOwner: false,
      displayOnly: true,
      selectedEmoji:
          widget.selectedEmojisByScopeId[_postScopeId(feedItem.post.id)],
      onEmojiSelected: (emoji) =>
          widget.onEmojiSelected(feedItem.post.id, emoji),
      pendingCommentDrafts: widget.pendingCommentDrafts,
      pendingVoiceComments: widget.pendingVoiceComments,
      taggingController: widget.taggingController,
      saveDelegate: widget.saveDelegate,
      onToggleAudio: (p) => widget.onToggleAudio(feedItem),
      onProfileImageDragged: widget.onProfileImageDragged,
      onCommentsReloadRequested: widget.onReloadComments,
      onLoadFullComments: widget.onLoadFullComments,
    );
  }

  /// 피드 본문은 단일 카드 refresh host와 일반 PageView 모드가 같은 고정형 레이아웃을 공유합니다.
  Widget _buildFeedContent({
    required FeedPostItem? currentPost,
    required bool isKeyboardVisible,
    required double composerBottomInset,
    required int itemCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 500.h, child: _buildMediaViewport(itemCount)),

            // 현재 포스트의 유저 정보 (고정)
            if (currentPost != null) ...[
              SizedBox(height: 12.h),
              ApiUserInfoWidget(
                post: currentPost.post,
                isCurrentUserPost:
                    widget.currentUserNickname != null &&
                    widget.currentUserNickname == currentPost.post.nickName,
                onDeletePressed: () =>
                    widget.onDeletePost(_currentIndex, currentPost),
                onCommentPressed: () {
                  final initialComments = _initialSheetCommentsForPost(
                    currentPost.post.id,
                  );
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return ChangeNotifierProvider(
                        create: (_) => AudioController(),
                        child: ApiVoiceCommentListSheet(
                          postId: currentPost.post.id,
                          initialComments: initialComments,
                          loadFullComments: widget.onLoadFullComments,
                          onCommentsUpdated: (updatedComments) {
                            if (!mounted) return;
                            setState(() {
                              _replaceCommentCaches(
                                currentPost.post.id,
                                updatedComments,
                              );
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 10.h),
              // 하단 CommentComposer 공간 확보
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: isKeyboardVisible ? 0 : 90.h,
              ),
            ],
          ],
        ),

        // 댓글 입력 위젯 (현재 포스트 기준 고정)
        if (currentPost != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: composerBottomInset),
              child: SoiTagComposerWidget(
                scopeId: _postScopeId(currentPost.post.id),
                pendingDrafts: widget.pendingCommentDrafts,
                mutationPort: widget.saveDelegate,
                avatarBuilder: SoiTaggingAvatarBuilders.buildComposerAvatar,
                onTextDraftSubmitted: (scopeId, text) =>
                    widget.onTextCommentCompleted(
                      SoiTaggingIds.postIdFromScopeId(scopeId),
                      text,
                    ),
                onAudioDraftRequested: _requestAudioDraft,
                onCameraDraftRequested: _requestCameraDraft,
                basePlaceholderText: 'comments.add_comment_placeholder'.tr(
                  context: context,
                ),
                textInputHintText: 'comments.add_comment_placeholder'.tr(
                  context: context,
                ),
                cameraIcon: Image.asset(
                  'assets/camera_button_baseBar.png',
                  width: 32.sp,
                  height: 32.sp,
                ),
                micIcon: Image.asset('assets/mic_icon.png'),
                resolveDropRelativePosition: (scopeId) =>
                    widget.pendingVoiceComments[scopeId]?.relativePosition,
                onCommentSaveProgress: (scopeId, progress) {
                  widget.onCommentSaveProgress(
                    SoiTaggingIds.postIdFromScopeId(scopeId),
                    progress,
                  );
                },
                onCommentSaveSuccess: (scopeId, comment) {
                  final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
                  final existingTagCountBefore = widget.taggingController
                      .peekTagComments(scopeId)
                      .length;
                  if (comment.hasLocation) {
                    unawaited(
                      _trackCommentTagSaved(
                        postId: postId,
                        categoryId: currentPost.categoryId,
                        tagContentType: _resolveTagContentType(
                          widget.pendingCommentDrafts[scopeId],
                        ),
                        existingTagCountBefore: existingTagCountBefore,
                        comment: comment,
                      ),
                    );
                  }
                  widget.onCommentSaveSuccess(postId, comment);
                },
                onCommentSaveFailure: (scopeId, error) {
                  widget.onCommentSaveFailure(
                    SoiTaggingIds.postIdFromScopeId(scopeId),
                    error,
                  );
                },
                onTextFieldFocusChanged: (isFocused) {
                  setState(() {
                    _isTextFieldFocused = isFocused;
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  /// 피드의 고정형 댓글 컴포저를 현재 키보드 높이에 맞춰 배치합니다.
  ///
  /// 홈 탭 바는 키보드가 열리면 부모에서 제거되므로, 입력창은 viewInsets를 그대로 따라가야 합니다.
  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = _isTextFieldFocused || keyboardInset > 0;
    final composerBottomInset = isKeyboardVisible ? keyboardInset + 10.0 : 10.0;

    // 페이지뷰의 아이템 수: 게시물 수 + (더 불러올 데이터가 있으면 로딩 인디케이터용 아이템 1개)
    final itemCount = widget.posts.length + (widget.hasMoreData ? 1 : 0);

    // 현재 페이지에 해당하는 게시물을 가져옵니다. 게시물이 없거나 인덱스가 범위를 벗어나면 null이 됩니다.
    // _currentPost는 getter로 정의되어있고, widget.posts와 _currentIndex를 참조하여 현재 게시물을 계산합니다.
    final currentPost = _currentPost;
    final content = _buildFeedContent(
      currentPost: currentPost,
      isKeyboardVisible: isKeyboardVisible,
      composerBottomInset: composerBottomInset,
      itemCount: itemCount,
    );
    if (_usesSinglePostRefreshScroll) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(hasScrollBody: false, child: content)],
      );
    }
    return content;
  }
}
