import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../../api/models/post.dart';
import '../../../../api/models/comment.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/controller/comment_controller.dart';
import '../../../../api/controller/category_controller.dart' as api_category;
import '../../../../api/controller/friend_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/media_controller.dart';
import '../../../../api/controller/audio_controller.dart';
import '../../../../utils/snackbar_utils.dart';
import '../../../../features/tagging_soi/tagging_soi.dart';
import '../../../common_widget/photo/photo_card_widget.dart';
import '../../../common_widget/photo/user_info_widget.dart';
import '../../../common_widget/comment/comment_list_bottom_sheet.dart';
import '../../../../api/models/friend.dart';

/// API 기반 사진 상세 화면
///
/// Firebase 버전의 PhotoDetailScreen과 동일한 디자인을 유지하면서
/// REST API와 공통 위젯을 사용합니다.
class ApiPhotoDetailScreen extends StatefulWidget {
  final List<Post> allPosts;
  final int initialIndex;
  final String categoryName;
  final int categoryId;
  final bool singlePostMode;
  final bool forceParentCommentsReloadOnEntry;

  const ApiPhotoDetailScreen({
    super.key,
    required this.allPosts,
    required this.initialIndex,
    required this.categoryName,
    required this.categoryId,
    this.singlePostMode = false,
    this.forceParentCommentsReloadOnEntry = false,
  });

  @override
  State<ApiPhotoDetailScreen> createState() => _ApiPhotoDetailScreenState();
}

class _ApiPhotoDetailScreenState extends State<ApiPhotoDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  late List<Post> _posts;
  late final AudioController _audioController;

  final Set<int> _deletedPostIds =
      <int>{}; // 삭제된 게시물 ID 추적 --> 상위 위젯에 전달하기 위해 사용됩니다.
  final Set<int> _deletingPostIds = <int>{};
  bool _allowPopWithDeletionResult = false;

  // 사용자 프로필 관련
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;
  int _profileLoadGeneration = 0;

  // 컨트롤러
  UserController? _userController;
  FriendController? _friendController;
  VoidCallback? _friendListener;
  int _lastBlockedFriendsRevision = 0;
  SoiTaggingController? _taggingController;
  TagMutationPort? _taggingSaveDelegate;
  VoidCallback? _taggingControllerListener;

  // 상태 맵 (Firebase 버전과 동일한 구조)
  final Map<String, String> _userProfileImages = {};
  final Map<String, bool> _profileLoadingStates = {};
  final Map<String, String> _userNames = {};
  final Map<int, String> _resolvedAudioUrls = {};
  bool _isTextFieldFocused = false;

  /// 상세 화면의 post 식별자를 tagging 모듈이 이해하는 scope 식별자로 감쌉니다.
  TagScopeId _postScopeId(int postId) => SoiTaggingIds.postScopeId(postId);

  Map<TagScopeId, String?> get _selectedEmojisByScopeId =>
      _taggingController?.selectedEmojisByScopeId ??
      const <TagScopeId, String?>{};

  Map<TagScopeId, TagDraft> get _pendingCommentDrafts =>
      _taggingController?.pendingDrafts ?? const <TagScopeId, TagDraft>{};

  Map<TagScopeId, TagPendingMarker> get _pendingCommentMarkers =>
      _taggingController?.pendingMarkers ??
      const <TagScopeId, TagPendingMarker>{};

  void _setSelectedEmoji(int postId, String? emoji) {
    _taggingController?.setSelectedEmoji(_postScopeId(postId), emoji);
  }

  /// 태깅 draft는 작성자 ID/핸들/프로필 source만 알면 생성할 수 있습니다.
  TagAuthor? _currentTaggingAuthor() {
    final currentUser = _userController?.currentUser;
    if (currentUser == null) {
      return null;
    }

    return TagAuthor(
      id: SoiTaggingIds.entityIdFromInt(currentUser.id)!,
      handle: currentUser.userId,
      profileImageSource: currentUser.profileImageKey,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _posts = List<Post>.from(
      widget.allPosts,
    ); // 자식 위젯에서 부모가 건네준 allPosts 수정을 방지하기 위해서, 복사본 생성
    _pageController = PageController(initialPage: _currentIndex);
    _audioController = AudioController();
    _userController = Provider.of<UserController>(context, listen: false);
    _friendController = Provider.of<FriendController>(context, listen: false);
    _taggingController = SoiTaggingFactory.createSessionController(context);
    _taggingSaveDelegate = SoiTaggingFactory.createSaveDelegate(context);
    _taggingControllerListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _taggingController!.addListener(_taggingControllerListener!);
    _lastBlockedFriendsRevision =
        _friendController?.blockedFriendsRevision ?? 0;
    if (!widget.singlePostMode) {
      _friendListener = () {
        final friendController = _friendController;
        if (!mounted || friendController == null) return;
        final nextRevision = friendController.blockedFriendsRevision;
        if (nextRevision == _lastBlockedFriendsRevision) {
          return;
        }
        _lastBlockedFriendsRevision = nextRevision;
        unawaited(_refreshPostsForBlockStatus());
      };
      _friendController?.addListener(_friendListener!);
    }
    unawaited(_loadUserProfileImage());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.forceParentCommentsReloadOnEntry) {
        unawaited(
          _loadParentCommentsForPost(
            _posts[_currentIndex].id,
            forceReload: true,
          ),
        );
        return;
      }

      // 초기 댓글 로드는 부모 댓글 미리보기 기준으로 태그 cache를 함께 맞춥니다.
      unawaited(_loadParentCommentsForPost(_posts[_currentIndex].id));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stopAudio();
    _audioController.dispose();
    if (_friendListener != null) {
      _friendController?.removeListener(_friendListener!);
      _friendListener = null;
    }
    if (_taggingControllerListener != null && _taggingController != null) {
      _taggingController!.removeListener(_taggingControllerListener!);
    }
    _taggingController?.dispose();
    // (배포버전 프리즈 방지) 전역 imageCache.clear()는 캐시가 큰 실사용 환경에서
    // dispose 타이밍에 수 초 프리즈를 만들 수 있어 제거합니다.
    super.dispose();
  }

  /// 차단 상태가 바뀌면 현재 카테고리 상세 목록을 다시 계산해 숨겨야 할 post를 즉시 반영합니다.
  Future<void> _refreshPostsForBlockStatus() async {
    if (widget.singlePostMode) {
      return;
    }
    await _refreshCategoryPosts();
  }

  /// 당겨서 새로고침 시 현재 화면 모드에 맞는 post 목록과 현재 post의 태그 상태를 서버 기준으로 다시 맞춥니다.
  Future<void> _handleRefresh() async {
    if (_posts.isEmpty) {
      return;
    }

    if (widget.singlePostMode) {
      await _refreshSinglePostDetail();
      return;
    }

    await _refreshCategoryPosts(forceRefresh: true);
  }

  /// 단건 상세 모드에서는 현재 post 상세를 다시 받아 화면과 부모 댓글 미리보기를 최신 상태로 교체합니다.
  Future<void> _refreshSinglePostDetail() async {
    final currentPostId = _posts[_currentIndex].id;
    final refreshedPost = await context.read<PostController>().getPostDetail(
      currentPostId,
    );
    if (!mounted || refreshedPost == null) {
      return;
    }

    _invalidateDetailCommentCaches(postIds: <int>{currentPostId});

    setState(() {
      _posts = <Post>[refreshedPost];
      _currentIndex = 0;
    });

    unawaited(_loadUserProfileImage());
    await _loadParentCommentsForPost(refreshedPost.id, forceReload: true);
  }

  /// 카테고리 상세는 현재 보던 post를 유지하면서 목록을 강제 새로고침하고 현재 post의 원댓글 미리보기를 함께 갱신합니다.
  Future<void> _refreshCategoryPosts({bool forceRefresh = false}) async {
    if (!mounted) return;

    final userController = _userController ?? context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) return;

    final postController = context.read<PostController>();
    final friendController =
        _friendController ?? context.read<FriendController>();
    final currentPostId = _posts.isNotEmpty ? _posts[_currentIndex].id : null;

    final posts = await postController.getPostsByCategory(
      categoryId: widget.categoryId,
      userId: currentUser.id,
      notificationId: null,
      forceRefresh: forceRefresh,
    );

    final blockedUsers = await friendController.getAllFriends(
      userId: currentUser.id,
      status: FriendStatus.blocked,
    );
    final blockedIds = blockedUsers.map((user) => user.userId).toSet();
    final filteredPosts = posts
        .where((post) => !blockedIds.contains(post.nickName))
        .toList(growable: false);

    if (!mounted) return;
    if (filteredPosts.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    var nextIndex = 0;
    if (currentPostId != null) {
      final foundIndex = filteredPosts.indexWhere(
        (post) => post.id == currentPostId,
      );
      nextIndex = foundIndex >= 0 ? foundIndex : 0;
    }

    final refreshedPostId = filteredPosts[nextIndex].id;
    final affectedPostIds = <int>{
      ..._posts.map((post) => post.id),
      ...filteredPosts.map((post) => post.id),
    };
    _invalidateDetailCommentCaches(postIds: affectedPostIds);

    setState(() {
      _posts = filteredPosts;
      _currentIndex = nextIndex;
    });

    if (_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_currentIndex);
      });
    }

    unawaited(_loadUserProfileImage());
    await _loadParentCommentsForPost(refreshedPostId, forceReload: true);
  }

  /// 새로고침으로 바뀐 상세 목록은 댓글/이모지 캐시를 비워 다음 렌더가 최신 서버 데이터를 다시 읽게 합니다.
  void _invalidateDetailCommentCaches({required Set<int> postIds}) {
    final commentController = context.read<CommentController>();
    for (final postId in postIds) {
      commentController.invalidatePostCaches(postId: postId);
      _taggingController?.clearScopeState(_postScopeId(postId));
    }
  }

  /// 게시물이 한 장뿐인 경우에는 PageView 대신 refresh 전용 scroll host를 사용해 Android pull-to-refresh를 안정화합니다.
  bool get _usesSinglePostRefreshScroll => _posts.length == 1;

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = _isTextFieldFocused || keyboardInset > 0;
    final composerBottomInset = isKeyboardVisible ? keyboardInset + 10.0 : 55.0;

    final platform = Theme.of(context).platform;
    final allowSystemGesturePopWithDeletion =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final shouldBlockPopForDeletionResult =
        _deletedPostIds.isNotEmpty &&
        !_allowPopWithDeletionResult &&
        !allowSystemGesturePopWithDeletion;

    return ChangeNotifierProvider<AudioController>.value(
      value: _audioController,
      child: PopScope(
        canPop: !shouldBlockPopForDeletionResult,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_deletedPostIds.isEmpty) return;
          _popWithDeletionResult();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.black,
            title: Text(
              widget.categoryName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              // 다운로드 버튼 (미디어가 있는 게시물에서만 표시)
              if (_posts.isNotEmpty && _posts[_currentIndex].hasMedia)
                Padding(
                  padding: EdgeInsets.only(right: 23.w),
                  child: IconButton(
                    onPressed: _downloadPhoto,
                    icon: Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 24.w,
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.white,
            backgroundColor: Colors.black,
            child: _buildRefreshContent(
              isKeyboardVisible: isKeyboardVisible,
              composerBottomInset: composerBottomInset,
            ),
          ),
        ),
      ),
    );
  }

  /// 게시물 수에 따라 PageView 또는 단일 카드 refresh host를 선택해 Android에서도 당겨서 새로고침이 동작하게 합니다.
  Widget _buildRefreshContent({
    required bool isKeyboardVisible,
    required double composerBottomInset,
  }) {
    final content = _buildDetailContent(
      isKeyboardVisible: isKeyboardVisible,
      composerBottomInset: composerBottomInset,
    );
    if (_usesSinglePostRefreshScroll) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(hasScrollBody: false, child: content)],
      );
    }
    return content;
  }

  /// 상세 본문은 단일 카드 refresh host와 일반 PageView 모드가 같은 고정형 레이아웃을 공유합니다.
  Widget _buildDetailContent({
    required bool isKeyboardVisible,
    required double composerBottomInset,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 500.h, child: _buildPhotoViewport()),

            // 현재 게시물의 작성자 정보 (화면에 고정)
            if (_posts.isNotEmpty && _currentIndex < _posts.length) ...[
              SizedBox(height: 12.h),
              Builder(
                builder: (context) {
                  final post = _posts[_currentIndex];
                  final currentUserId = _userController?.currentUser?.userId;
                  final isOwner = currentUserId == post.nickName;
                  return ApiUserInfoWidget(
                    post: post,
                    isCurrentUserPost: isOwner,
                    onDeletePressed: () => _deletePost(post),
                    onCommentPressed: () {
                      final comments = _initialSheetCommentsForPost(post.id);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) {
                          return ChangeNotifierProvider(
                            create: (_) => AudioController(),
                            child: ApiVoiceCommentListSheet(
                              postId: post.id,
                              initialComments: comments,
                              loadFullComments: _loadFullCommentsForPost,
                              onCommentsUpdated: (updatedComments) {
                                if (!mounted) return;
                                setState(() {
                                  _replaceCommentCaches(
                                    post.id,
                                    updatedComments,
                                  );
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 10.h),
              // 댓글 입력창 공간 확보
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: isKeyboardVisible ? 0 : 90.h,
              ),
            ],
          ],
        ),

        // 댓글 입력창 (화면에 고정)
        // 키보드가 올라오면 viewInsets.bottom 만큼 위로 올라가고,
        // 키보드가 없으면 탭바 위 55px에 위치합니다.
        if (_posts.isNotEmpty && _currentIndex < _posts.length)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: composerBottomInset),
              child: SoiTagComposerWidget(
                scopeId: _postScopeId(_posts[_currentIndex].id),
                pendingDrafts: _pendingCommentDrafts,
                mutationPort: _taggingSaveDelegate!,
                avatarBuilder: SoiTaggingAvatarBuilders.buildComposerAvatar,
                onTextDraftSubmitted: (scopeId, text) async {
                  await _onTextCommentCreated(
                    SoiTaggingIds.postIdFromScopeId(scopeId),
                    text,
                  );
                },
                onAudioDraftRequested: (scopeId) {
                  final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
                  return SoiTaggingComposerActions.requestAudioDraft(
                    context: context,
                    onSelected: (audioPath, waveformData, durationMs) async {
                      await _onAudioCommentCompleted(
                        postId,
                        audioPath,
                        waveformData,
                        durationMs,
                      );
                    },
                  );
                },
                onCameraDraftRequested: (scopeId) {
                  final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
                  return SoiTaggingComposerActions.requestCameraDraft(
                    context: context,
                    onSelected: (localFilePath, isVideo) async {
                      await _onMediaCommentCompleted(
                        postId,
                        localFilePath,
                        isVideo,
                      );
                    },
                  );
                },
                basePlaceholderText: tr(
                  'comments.add_comment_placeholder',
                  context: context,
                ),
                textInputHintText: tr(
                  'comments.add_comment_placeholder',
                  context: context,
                ),
                cameraIcon: Image.asset(
                  'assets/camera_button_baseBar.png',
                  width: 32.sp,
                  height: 32.sp,
                ),
                micIcon: Image.asset('assets/mic_icon.png'),
                resolveDropRelativePosition: (scopeId) =>
                    _pendingCommentMarkers[scopeId]?.relativePosition,
                onCommentSaveProgress: (scopeId, progress) {
                  _onCommentSaveProgress(
                    SoiTaggingIds.postIdFromScopeId(scopeId),
                    progress,
                  );
                },
                onCommentSaveSuccess: (scopeId, comment) {
                  _onCommentSaveSuccess(
                    SoiTaggingIds.postIdFromScopeId(scopeId),
                    comment,
                  );
                },
                onCommentSaveFailure: (scopeId, error) {
                  _onCommentSaveFailure(
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

  /// 게시물 수에 따라 PageView 또는 단일 카드를 선택해 refresh 제스처와 페이지 스와이프를 함께 보장합니다.
  Widget _buildPhotoViewport() {
    if (_usesSinglePostRefreshScroll) {
      return _buildPhotoCard(_posts.first, 0);
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _posts.length,
      scrollDirection: Axis.vertical,
      clipBehavior: Clip.hardEdge,
      physics: const AlwaysScrollableScrollPhysics(parent: PageScrollPhysics()),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) => _buildPhotoCard(_posts[index], index),
    );
  }

  /// 상세 카드 한 장의 공통 조립을 분리해 단일 카드/페이지뷰 모드가 같은 UI를 공유하게 합니다.
  Widget _buildPhotoCard(Post post, int index) {
    final currentUserId = _userController?.currentUser?.userId;
    final isOwner = currentUserId == post.nickName;

    if (!_userProfileImages.containsKey(post.nickName)) {
      _userProfileImages[post.nickName] = _userProfileImageUrl;
      _profileLoadingStates[post.nickName] = _isLoadingProfile;
      _userNames[post.nickName] = _userName;
    }

    return ApiPhotoCardWidget(
      key: ValueKey(post.id),
      post: post,
      categoryName: widget.categoryName,
      categoryId: widget.categoryId,
      index: index,
      isOwner: isOwner,
      isArchive: true,
      isCategory: true,
      displayOnly: true,
      selectedEmoji: _selectedEmojisByScopeId[_postScopeId(post.id)],
      onEmojiSelected: (emoji) => _setSelectedEmoji(post.id, emoji),
      pendingCommentDrafts: _pendingCommentDrafts,
      pendingVoiceComments: _pendingCommentMarkers,
      taggingController: _taggingController!,
      saveDelegate: _taggingSaveDelegate!,
      onToggleAudio: _toggleAudio,
      onProfileImageDragged: (postId, absolutePosition) {
        _onProfileImageDragged(postId, absolutePosition);
      },
      onCommentsReloadRequested: _reloadCommentsForPost,
      onLoadFullComments: _loadFullCommentsForPost,
    );
  }

  /// 페이지 변경 시 처리
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _stopAudio();
    unawaited(_loadUserProfileImage());
    unawaited(_loadParentCommentsForPost(_posts[index].id));
  }

  /// 서버가 내려준 URL을 즉시 표시용 값으로 정규화합니다.
  String? _normalizeImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 미디어/프로필 key를 캐시 식별과 presigned URL 재발급 기준으로 정규화합니다.
  String? _normalizeImageKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 상세 화면 작성자 프로필은 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateProfileImageUrl(Post post) {
    final immediateUrl = _normalizeImageUrl(post.userProfileImageUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final profileKey = _normalizeImageKey(post.userProfileImageKey);
    if (profileKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(profileKey);
    } catch (_) {
      return null;
    }
  }

  /// 상세 화면 미디어는 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateMediaUrl(Post post) {
    final immediateUrl = _normalizeImageUrl(post.postFileUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final mediaKey = _normalizeImageKey(post.postFileKey);
    if (mediaKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(mediaKey);
    } catch (_) {
      return null;
    }
  }

  /// 현재 게시물 작성자 프로필은 URL을 먼저 표시하고, key가 있으면 최신 presigned URL로 백그라운드 갱신합니다.
  Future<void> _loadUserProfileImage() async {
    final currentPost = _posts[_currentIndex];
    final requestId = ++_profileLoadGeneration;
    final immediateUrl = _resolveImmediateProfileImageUrl(currentPost);
    final profileKey = _normalizeImageKey(currentPost.userProfileImageKey);

    if (!mounted) return;
    setState(() {
      _userProfileImageUrl = immediateUrl ?? '';
      _userName = currentPost.nickName;
      _isLoadingProfile = immediateUrl == null && profileKey != null;
      _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
      _profileLoadingStates[currentPost.nickName] = _isLoadingProfile;
      _userNames[currentPost.nickName] = _userName;
    });

    if (profileKey == null) {
      return;
    }

    try {
      final resolvedUrl = _normalizeImageUrl(
        await context.read<MediaController>().getPresignedUrl(profileKey),
      );
      if (!mounted || requestId != _profileLoadGeneration) {
        return;
      }

      setState(() {
        _userProfileImageUrl = resolvedUrl ?? immediateUrl ?? '';
        _userName = currentPost.nickName;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
        _profileLoadingStates[currentPost.nickName] = false;
        _userNames[currentPost.nickName] = _userName;
      });
    } catch (_) {
      if (!mounted || requestId != _profileLoadGeneration) {
        return;
      }

      setState(() {
        _userProfileImageUrl = immediateUrl ?? '';
        _userName = currentPost.nickName;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
        _profileLoadingStates[currentPost.nickName] = false;
        _userNames[currentPost.nickName] = _userName;
      });
    }
  }

  /// 다운로드는 즉시 URL을 우선 사용하고, 없을 때만 key로 최신 presigned URL을 발급받아 진행합니다.
  Future<String?> _resolveMediaUrl(Post post) async {
    final immediateUrl = _resolveImmediateMediaUrl(post);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final mediaKey = _normalizeImageKey(post.postFileKey);
    if (mediaKey == null) {
      return null;
    }

    return _normalizeImageUrl(
      await context.read<MediaController>().getPresignedUrl(mediaKey),
    );
  }

  /// 상세 화면 초기 렌더와 새로고침은 부모 댓글 미리보기 기준으로 태그와 시트 초기값을 함께 최신화합니다.
  Future<List<Comment>> _loadParentCommentsForPost(
    int postId, {
    bool forceReload = false,
  }) async {
    final comments = await _taggingController?.loadParentCommentsForScope(
      _postScopeId(postId),
      forceReload: forceReload,
    );
    return comments == null
        ? const <Comment>[]
        : SoiTagCommentMapper.toComments(comments);
  }

  /// 댓글시트는 full thread를 캐시해 재오픈 시 네트워크 비용을 줄입니다.
  Future<List<Comment>> _loadFullCommentsForPost(
    int postId, {
    bool forceReload = false,
  }) async {
    final comments = await _taggingController?.loadCommentsForScope(
      _postScopeId(postId),
      forceReload: forceReload,
    );
    return comments == null
        ? const <Comment>[]
        : SoiTagCommentMapper.toComments(comments);
  }

  /// overlay 삭제 후에는 이미 가진 cache 범위에 맞춰 full/parent/tag 중 필요한 조회만 다시 수행합니다.
  Future<void> _reloadCommentsForPost(int postId) async {
    if (context.read<CommentController>().peekCommentsCache(postId: postId) !=
        null) {
      await _loadFullCommentsForPost(postId, forceReload: true);
      return;
    }
    if (context.read<CommentController>().peekParentCommentsCache(
          postId: postId,
        ) !=
        null) {
      await _loadParentCommentsForPost(postId, forceReload: true);
      return;
    }
    await _loadParentCommentsForPost(postId, forceReload: true);
  }

  /// 댓글 시트는 full cache가 없을 때 원댓글 미리보기를 먼저 보여 주고, 없으면 태그 캐시로 즉시 엽니다.
  List<Comment> _initialSheetCommentsForPost(int postId) {
    final commentController = context.read<CommentController>();
    final fullComments = commentController.peekCommentsCache(postId: postId);
    if (fullComments != null && fullComments.isNotEmpty) {
      return fullComments;
    }
    final parentComments = commentController.peekParentCommentsCache(
      postId: postId,
    );
    if (parentComments != null && parentComments.isNotEmpty) {
      return parentComments;
    }
    return commentController.peekTagCommentsCache(postId: postId) ??
        const <Comment>[];
  }

  /// 댓글 시트에서 수정된 전체 스레드는 controller cache와 로컬 이모지 상태를 같은 기준으로 다시 맞춥니다.
  void _replaceCommentCaches(int postId, List<Comment> comments) {
    _taggingController?.replaceCommentsCache(
      _postScopeId(postId),
      SoiTagCommentMapper.fromComments(
        comments,
        scopeId: _postScopeId(postId),
      ),
    );
  }

  /// 프로필 이미지 드래그 시 위치 업데이트 처리
  ///
  /// Parameters:
  /// - [postId]: 프로필 이미지가 드래그된 게시물 ID
  /// - [absolutePosition]: 드래그된 절대 위치
  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    _taggingController?.updatePendingMarkerFromAbsolutePosition(
      scopeId: _postScopeId(postId),
      absolutePosition: TagPosition(
        x: absolutePosition.dx,
        y: absolutePosition.dy,
      ),
      viewportSize: TagViewportSize(width: 354.w, height: 500.h),
    );
  }

  /// 오디오 토글 처리
  ///
  /// Parameters:
  ///   - [post]: 오디오 토글할 게시물 객체
  Future<void> _toggleAudio(Post post) async {
    if (!post.hasAudio) return;
    final audioKey = post.audioUrl;
    if (audioKey == null || audioKey.isEmpty) return;
    try {
      var resolved = audioKey;
      final uri = Uri.tryParse(audioKey);
      if (uri == null || !uri.hasScheme) {
        final mediaController = context.read<MediaController>();
        resolved = await mediaController.getPresignedUrl(audioKey) ?? '';
      }
      if (resolved.isEmpty) return;
      _resolvedAudioUrls[post.id] = resolved;
      await _audioController.togglePlayPause(resolved);
    } catch (e) {
      debugPrint('오디오 토글 실패: $e');
    }
  }

  /// 텍스트 댓글 생성 처리
  ///
  /// Parameters:
  ///   - [postId]: 댓글이 생성될 게시물 ID
  /// - [text]: 생성할 텍스트 댓글 내용
  Future<void> _onTextCommentCreated(int postId, String text) async {
    try {
      final author = _currentTaggingAuthor();
      if (author == null) return;
      _taggingController?.stageTextDraft(
        scopeId: _postScopeId(postId),
        text: text,
        author: author,
      );
    } catch (e) {
      debugPrint('텍스트 댓글 임시 저장 실패: $e');
    }
  }

  Future<void> _onAudioCommentCompleted(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  ) async {
    try {
      final author = _currentTaggingAuthor();
      if (author == null) return;
      _taggingController?.stageAudioDraft(
        scopeId: _postScopeId(postId),
        audioPath: audioPath,
        waveformData: waveformData,
        durationMs: durationMs,
        author: author,
      );
    } catch (e) {
      debugPrint('음성 댓글 임시 저장 실패: $e');
    }
  }

  Future<void> _onMediaCommentCompleted(
    int postId,
    String localFilePath,
    bool isVideo,
  ) async {
    try {
      final author = _currentTaggingAuthor();
      if (author == null) return;
      _taggingController?.stageMediaDraft(
        scopeId: _postScopeId(postId),
        localFilePath: localFilePath,
        isVideo: isVideo,
        author: author,
      );
    } catch (e) {
      debugPrint('미디어 댓글 임시 저장 실패: $e');
    }
  }

  void _updatePendingProgress(int postId, double progress) {
    _taggingController?.updatePendingProgress(_postScopeId(postId), progress);
  }

  void _onCommentSaveProgress(int postId, double progress) {
    _updatePendingProgress(postId, progress);
  }

  void _onCommentSaveSuccess(int postId, TagComment comment) {
    _taggingController?.handleCommentSaveSuccess(_postScopeId(postId), comment);
  }

  void _onCommentSaveFailure(int postId, Object error) {
    debugPrint('댓글 저장 실패(postId: $postId): $error');
    _taggingController?.handleCommentSaveFailure(_postScopeId(postId));
  }

  // 게시물 삭제 처리
  Future<void> _deletePost(Post post) async {
    if (_deletingPostIds.contains(post.id)) return;
    _deletingPostIds.add(post.id);
    try {
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      debugPrint("사진 삭제 시도: postId=${post.id}");

      // MoreMenuButton의 '사진 삭제' 바텀시트에서 이미 확인을 받았으므로,
      // 여기서는 추가 다이얼로그 없이 바로 상태를 DELETED로 변경합니다.
      final success = await postController.setPostStatus(
        postId: post.id,
        postStatus: PostStatus.deleted,
      );

      if (!mounted) return;
      if (success) {
        _deletedPostIds.add(post.id);
        _showSnackBar(tr('archive.photo_deleted', context: context));

        // 삭제 후 처리
        _handleSuccessfulDeletion(post);

        final userId = _userController?.currentUser?.id;
        if (userId != null) {
          unawaited(
            Provider.of<api_category.CategoryController>(
              context,
              listen: false,
            ).loadCategories(userId, forceReload: true),
          );
        }
      } else {
        _showSnackBar(tr('archive.delete_error', context: context));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        tr(
          'archive.delete_error_with_reason',
          context: context,
          namedArgs: {'error': e.toString()},
        ),
      );
      debugPrint('사진 삭제 실패: $e');
    } finally {
      _deletingPostIds.remove(post.id);
    }
  }

  void _popWithDeletionResult() {
    if (_allowPopWithDeletionResult) return;
    setState(() => _allowPopWithDeletionResult = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(_deletedPostIds.toList(growable: false));
    });
  }

  /// 게시물 삭제 후, 해당 게시물과 관련된 상태를 정리하는 함수
  ///
  /// Parameters:
  /// - [postId]: 삭제된 게시물 ID
  /// - [nickName]: 삭제된 게시물 작성자의 닉네임 (사용자 캐시 정리를 위해 필요)
  void _clearPostScopedState(int postId, {required String nickName}) {
    context.read<CommentController>().invalidatePostCaches(postId: postId);
    _taggingController?.clearScopeState(_postScopeId(postId));
    _resolvedAudioUrls.remove(postId);

    final hasOtherPostsByNickname = _posts.any(
      (existingPost) =>
          existingPost.id != postId && existingPost.nickName == nickName,
    );
    if (!hasOtherPostsByNickname) {
      _userProfileImages.remove(nickName);
      _profileLoadingStates.remove(nickName);
      _userNames.remove(nickName);
    }
  }

  // 삭제 후 상태 업데이트 처리
  void _handleSuccessfulDeletion(Post post) {
    _clearPostScopedState(post.id, nickName: post.nickName);

    if (_posts.length <= 1) {
      if (_deletedPostIds.isEmpty) {
        Navigator.of(context).pop();
      } else {
        _popWithDeletionResult();
      }
      return;
    }
    setState(() {
      // 현재 인덱스 조정
      _posts.removeWhere((p) => p.id == post.id);
      if (_currentIndex >= _posts.length) {
        _currentIndex = _posts.length - 1;
      }
    });

    if (_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_pageController.hasClients) return;
        if (_currentIndex < 0 || _currentIndex >= _posts.length) return;
        _pageController.jumpToPage(_currentIndex);
      });
    }

    // profile 이미지 및 댓글 재로딩
    unawaited(_loadUserProfileImage());
    unawaited(_loadParentCommentsForPost(_posts[_currentIndex].id));
  }

  Future<void> _stopAudio() async {
    await _audioController.stopRealtimeAudio();
  }

  /// 미디어(사진/비디오) 다운로드 처리
  Future<void> _downloadPhoto() async {
    try {
      final currentPost = _posts[_currentIndex];
      final mediaUrl = await _resolveMediaUrl(currentPost);

      if (mediaUrl == null || mediaUrl.isEmpty) {
        _showSnackBar('다운로드할 미디어가 없습니다.');
        return;
      }

      final isVideo = currentPost.isVideo;

      // 미디어 다운로드
      final response = await http.get(Uri.parse(mediaUrl));

      if (response.statusCode != 200) {
        _showSnackBar('다운로드에 실패했습니다.');
        return;
      }

      final Uint8List bytes = response.bodyBytes;

      if (isVideo) {
        // 비디오의 경우: 임시 파일로 저장 후 갤러리에 저장
        final tempDir = await getTemporaryDirectory();
        final fileName = "SOI_${DateTime.now().millisecondsSinceEpoch}.mp4";
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);

        await Gal.putVideo(tempFile.path);

        // 임시 파일 삭제
        try {
          await tempFile.delete();
        } catch (_) {}
      } else {
        // 이미지의 경우: 바로 저장
        await Gal.putImageBytes(bytes);
      }

      _showSnackBar('갤러리에 저장되었습니다.');
    } catch (e) {
      debugPrint('다운로드 실패: $e');
      _showSnackBar('다운로드 중 오류가 발생했습니다.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }
}
