import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/category_controller.dart' as api_category;
import '../../api/controller/comment_controller.dart';
import '../../api/controller/post_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/comment.dart';
import '../../api/models/post.dart' show PostStatus;
import '../../features/tagging_soi/tagging_soi.dart';
import 'manager/feed_audio_manager.dart';
import 'manager/feed_data_manager.dart';
import 'widgets/feed_page_builder.dart';
import '../../utils/snackbar_utils.dart';
import '../../utils/tab_reselect_registry.dart';

class FeedHomeScreen extends StatefulWidget {
  const FeedHomeScreen({super.key});

  @override
  State<FeedHomeScreen> createState() => _FeedHomeScreenState();
}

class _FeedHomeScreenState extends State<FeedHomeScreen> {
  // FeedDataManager는 전역 Provider에서 가져와 캐시를 유지합니다.
  // FeedDataManager를 Provider로 만들어서, 여러 화면에서 동일한 인스턴스를 사용하도록 합니다.
  FeedDataManager? _feedDataManager;

  // 피드와 상세가 공유하는 태깅 상태/저장 추상화입니다.
  SoiTaggingController? _taggingController;
  TagMutationPort? _taggingSaveDelegate;
  VoidCallback? _taggingControllerListener;

  // 오디오 매니저
  FeedAudioManager? _feedAudioManager;

  // 탭 재선택 시 첫 게시물로 이동용 페이지 컨트롤러
  final PageController _feedPageController = PageController();
  int _currentFeedIndex = 0;

  // 사용자 컨트롤러 및 프로필 이미지 키 추적
  UserController? _userController;
  VoidCallback? _userControllerListener;
  String? _lastProfileImageKey;
  final Set<int> _deletingPostIds = <int>{};

  /// SOI post 식별자를 tagging 모듈의 범용 scope 식별자로 변환합니다.
  TagScopeId _postScopeId(int postId) => SoiTaggingIds.postScopeId(postId);

  @override
  void initState() {
    super.initState();

    // 홈 탭(인덱스 0) 재선택 시, 호출될 콜백 등록
    TabReselectRegistry.register(0, _onFeedTabReselected);

    // 오디오 매니저 초기화
    _feedAudioManager = FeedAudioManager();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FeedDataManager 인스턴스 가져오기
      _feedDataManager = Provider.of<FeedDataManager>(context, listen: false);

      // _feedDataManager instance를 가지고 온 후에,
      // 각 게시물에 대한 댓글을 로드하는 콜백 설정
      _feedDataManager?.setOnPostsLoaded((items) {
        if (!mounted) return;
        _loadParentCommentsForItems(_buildParentPreloadCandidates(items));
      });

      _userController = Provider.of<UserController>(context, listen: false);
      _lastProfileImageKey = _userController?.currentUser?.profileImageKey;
      _userControllerListener ??= _handleUserProfileChanged;
      _userController?.addListener(_userControllerListener!);

      // PostController 구독 설정
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      // FeedDataManager에 PostController 구독 시작
      _feedDataManager?.listenToPostController(postController, context);

      _loadInitialData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack 전환 시 TickerMode 변경을 의존성으로 추적해
    // 숨김 탭에서 누적된 posts-changed 갱신을 재개합니다.
    TickerMode.valuesOf(context);
    _userController ??= context.read<UserController>();
    if (_taggingController == null || _taggingSaveDelegate == null) {
      _taggingController = SoiTaggingFactory.createSessionController(context);
      _taggingSaveDelegate = SoiTaggingFactory.createSaveDelegate(context);
      _taggingControllerListener ??= () {
        if (mounted) {
          setState(() {});
        }
      };
      _taggingController!.addListener(_taggingControllerListener!);
    }
    _feedDataManager ??= Provider.of<FeedDataManager>(context, listen: false);
    _feedDataManager?.refreshIfPendingVisible();
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

  /// 초기 데이터 로드
  Future<void> _loadInitialData() async {
    if (_userController == null) return;
    // 피드 진입마다 매번 강제 리로드하지 않고, 캐시가 있으면 재사용합니다.
    await _feedDataManager?.loadUserCategoriesAndPhotos(context);
  }

  @override
  void dispose() {
    // 홈 탭 콜백 등록 해제
    TabReselectRegistry.unregister(0);

    // 탭 재선택 시 첫 게시물로 이동용 페이지 컨트롤러 해제
    _feedPageController.dispose();
    if (_userControllerListener != null) {
      _userController?.removeListener(_userControllerListener!);
    }
    if (_taggingControllerListener != null && _taggingController != null) {
      _taggingController!.removeListener(_taggingControllerListener!);
    }
    // FeedDataManager는 전역 Provider가 소유하므로 여기서 dispose 하면 캐시가 날아가거나
    // "disposed object" 에러가 날 수 있습니다. 화면이 사라질 때는 리스너만 해제합니다.
    _feedDataManager?.detachFromPostController();

    _taggingController?.dispose();

    super.dispose();
  }

  /// 피드 아이콘을 다시 누르면 현재 위치와 상관없이 첫 게시물로 복귀하고 강제 새로고침을 시작합니다.
  void _onFeedTabReselected() {
    if (!mounted) return;
    if (_feedPageController.hasClients) {
      _feedPageController.jumpToPage(0);
    }
    if (_feedDataManager != null) {
      _currentFeedIndex = 0;
      unawaited(_handleFeedRefresh());
    }
  }

  /// 사진 게시물 삭제 처리
  ///
  /// Parameters:
  /// - [index]: 삭제할 게시물의 인덱스
  /// - [item]: 삭제할 게시물 아이템
  Future<void> _deletePost(int index, FeedPostItem item) async {
    final postId = item.post.id;
    if (_deletingPostIds.contains(postId)) return;
    _deletingPostIds.add(postId);
    try {
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<api_category.CategoryController>(
        context,
        listen: false,
      );
      final userId = _userController?.currentUser?.id;
      final success = await postController.setPostStatus(
        postId: postId,
        postStatus: PostStatus.deleted,
      );
      if (!mounted) return;
      if (success) {
        context.read<CommentController>().invalidatePostCaches(postId: postId);
        setState(() {
          _feedDataManager?.removePhoto(
            index,
          ); // UI에서 즉시 제거 --> 서버에 접근하는 것이 아니라, UI단에서 제거하는 것.
          _taggingController?.clearScopeState(_postScopeId(item.post.id));
        });
        if (userId != null) {
          // 카테고리도 강제 새로고침 --> 댓글 수정을 반영하기 위함
          unawaited(
            categoryController.loadCategories(userId, forceReload: true),
          );
        }
        _showSnackBar('사진이 삭제되었습니다.');
      } else {
        _showSnackBar('사진 삭제에 실패했습니다.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('사진 삭제 중 오류가 발생했습니다.', isError: true);
    } finally {
      _deletingPostIds.remove(postId);
    }
  }

  /// 페이지 변경 처리 (무한 스크롤)
  void _handlePageChanged(int index) {
    _currentFeedIndex = index;
    final totalPosts = _feedDataManager?.visiblePosts.length ?? 0;
    if (totalPosts == 0) {
      return;
    }

    _loadParentCommentsAroundIndex(index);

    // 수정: 현재 5개를 보여줄 때 4번째(인덱스 3)에서 다음 5개를 미리 로드합니다.
    // (일반화: 끝에서 2번째에 도달하면 다음 청크를 요청)
    if (index >= totalPosts - 2 &&
        (_feedDataManager?.hasMoreData ?? false) &&
        !(_feedDataManager?.isLoadingMore ?? false)) {
      // 다음으로 가지고 올 게시물을 추가로 로드 --> 네트워크 요청이 아니라 UI 노출만 증가시킴
      unawaited(_feedDataManager?.loadMorePhotos(context));
    }
  }

  /// 음성 재생 토글
  Future<void> _toggleAudio(FeedPostItem item) async {
    await _feedAudioManager?.toggleAudio(item.post, context);
  }

  /// 텍스트 댓글 완료 처리
  ///
  /// Parameters:
  /// - [postId]: 댓글이 달린 게시물 ID
  /// - [text]: 작성된 텍스트 댓글 내용
  Future<void> _onTextCommentCompleted(int postId, String text) async {
    final author = _currentTaggingAuthor();
    if (author == null) return;
    _taggingController?.stageTextDraft(
      scopeId: _postScopeId(postId),
      text: text,
      author: author,
    );
  }

  Future<void> _onAudioCommentCompleted(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  ) async {
    final author = _currentTaggingAuthor();
    if (author == null) return;
    _taggingController?.stageAudioDraft(
      scopeId: _postScopeId(postId),
      audioPath: audioPath,
      waveformData: waveformData,
      durationMs: durationMs,
      author: author,
    );
  }

  Future<void> _onMediaCommentCompleted(
    int postId,
    String localFilePath,
    bool isVideo,
  ) async {
    final author = _currentTaggingAuthor();
    if (author == null) return;
    _taggingController?.stageMediaDraft(
      scopeId: _postScopeId(postId),
      localFilePath: localFilePath,
      isVideo: isVideo,
      author: author,
    );
  }

  /// 프로필 이미지 드래그 이벤트 처리
  ///
  /// Parameters:
  /// - [postId]: 댓글이 달린 게시물 ID
  /// - [absolutePosition]: 드래그된 프로필 이미지의 절대 위치
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

  void _onCommentSaveProgress(int postId, double progress) {
    _taggingController?.updatePendingProgress(_postScopeId(postId), progress);
  }

  /// 댓글 저장 성공 처리
  ///
  /// 댓글이 성공적으로 저장된 후, 새 댓글을 캐시에 추가하고 UI를 갱신합니다.
  ///
  /// Parameters:
  /// - [postId]: 댓글이 달린 게시물 ID
  /// - [comment]: 서버에서 저장되어 반환된 댓글 데이터
  void _onCommentSaveSuccess(int postId, TagComment comment) {
    _taggingController?.handleCommentSaveSuccess(_postScopeId(postId), comment);
  }

  void _onCommentSaveFailure(int postId, Object error) {
    debugPrint('댓글 저장 실패(postId: $postId): $error');
    _taggingController?.handleCommentSaveFailure(_postScopeId(postId));
  }

  /// 모든 오디오 정지
  void _stopAllAudio() {
    _feedAudioManager?.stopAllAudio(context);
  }

  /// 프로필 이미지 변경 감지 및 피드 새로고침
  void _handleUserProfileChanged() {
    // 현재 프로필 이미지 키 가져오기
    final newKey = _userController?.currentUser?.profileImageKey;

    // 프로필 이미지 키가 변경되지 않았으면 종료
    if (newKey == _lastProfileImageKey) {
      return;
    }

    // 프로필 이미지가 변경되었으므로, 마지막 키 업데이트
    _lastProfileImageKey = newKey;

    // 프로필 이미지가 변경되었으므로 피드 새로고침
    _refreshFeedAfterProfileUpdate();
  }

  /// 피드 새로고침 및 댓글 재로딩
  void _refreshFeedAfterProfileUpdate() {
    final posts = _feedDataManager?.allPosts ?? const <FeedPostItem>[];
    final commentController = context.read<CommentController>();
    if (posts.isNotEmpty) {
      for (final item in posts) {
        commentController.invalidatePostCaches(postId: item.post.id);
      }
    }

    // 피드 데이터 새로고침
    unawaited(
      // 사용자 카테고리 및 사진 로드
      _feedDataManager?.loadUserCategoriesAndPhotos(context).then((_) {
        if (!mounted) return;
        final refreshedPosts = _feedDataManager?.visiblePosts ?? const [];
        _loadParentCommentsForItems(refreshedPosts, forceReload: true);
        if (mounted) {
          setState(() {});
        }
      }),
    );
  }

  /// 당겨서 새로고침하면 현재 카드와 인접 카드의 원댓글 미리보기만 강제로 다시 받아 최신성과 체감 속도를 함께 맞춥니다.
  Future<void> _handleFeedRefresh() async {
    final previousVisiblePosts = _feedDataManager?.visiblePosts ?? const [];
    _invalidateFeedCommentCaches(
      previousVisiblePosts.map((item) => item.post.id),
    );

    await _feedDataManager?.loadUserCategoriesAndPhotos(
      context,
      forceRefresh: true,
    );
    if (!mounted) {
      return;
    }

    final refreshedVisiblePosts = _feedDataManager?.visiblePosts ?? const [];
    _invalidateFeedCommentCaches(
      refreshedVisiblePosts.map((item) => item.post.id),
    );
    final refreshTargets = _buildParentRefreshCandidates(refreshedVisiblePosts);
    if (refreshTargets.isNotEmpty) {
      await _taggingController?.loadParentCommentsForScopes(
        refreshTargets
            .map((item) => _postScopeId(item.post.id))
            .toList(growable: false),
        forceReload: true,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// refresh 경로에서는 stale full cache 재사용을 막기 위해 현재 보이는 카드들의 댓글 캐시와 선택 이모지를 함께 비웁니다.
  void _invalidateFeedCommentCaches(Iterable<int> postIds) {
    final commentController = context.read<CommentController>();
    final selectedEmojis = _taggingController?.selectedEmojisByScopeId;
    for (final postId in postIds.toSet()) {
      commentController.invalidatePostCaches(postId: postId);
      selectedEmojis?.remove(_postScopeId(postId));
    }
  }

  /// refresh 직후에는 현재 카드와 다음 카드까지만 원댓글 미리보기를 다시 받아 초기 네트워크 부하를 제한합니다.
  List<FeedPostItem> _buildParentRefreshCandidates(List<FeedPostItem> items) {
    if (items.isEmpty) {
      return const <FeedPostItem>[];
    }

    final startIndex = _currentFeedIndex.clamp(0, items.length - 1);
    final endIndex = (startIndex + 2) < items.length
        ? startIndex + 2
        : items.length;
    return items.sublist(startIndex, endIndex);
  }

  /// 현재/인접 post의 부모 댓글 미리보기를 선로딩해 태그 오버레이와 시트 초기값을 함께 안정화합니다.
  void _loadParentCommentsAroundIndex(int index) {
    final visiblePosts =
        _feedDataManager?.visiblePosts ?? const <FeedPostItem>[];
    if (visiblePosts.isEmpty || index < 0 || index >= visiblePosts.length) {
      return;
    }

    final upperBound = (index + 2) < visiblePosts.length
        ? (index + 2)
        : visiblePosts.length;
    _loadParentCommentsForItems(visiblePosts.sublist(index, upperBound));
  }

  /// 잠정 후보와 현재 visible post를 합쳐 새 상단 후보가 나타나도 부모 댓글 preload가 늦지 않게 합니다.
  List<FeedPostItem> _buildParentPreloadCandidates(List<FeedPostItem> items) {
    final currentVisible =
        _feedDataManager?.visiblePosts ?? const <FeedPostItem>[];
    final targetCount = currentVisible.isNotEmpty ? currentVisible.length : 5;
    final mergedByPostId = <int, FeedPostItem>{};

    for (final item in currentVisible.take(targetCount)) {
      mergedByPostId[item.post.id] = item;
    }
    for (final item in items.take(targetCount)) {
      mergedByPostId[item.post.id] = item;
    }

    return mergedByPostId.values.toList(growable: false);
  }

  /// 피드 preload는 `comment/getParentComment` 기반의 부모 댓글을 먼저 받아 태그 캐시를 함께 파생합니다.
  void _loadParentCommentsForItems(
    List<FeedPostItem> items, {
    bool forceReload = false,
  }) {
    if (!mounted || items.isEmpty) {
      return;
    }

    final postIds = items
        .map((item) => item.post.id)
        .toSet()
        .toList(growable: false);
    unawaited(
      _taggingController?.loadParentCommentsForScopes(
        postIds.map(_postScopeId).toList(growable: false),
        forceReload: forceReload,
      ),
    );
  }

  /// 태그 삭제 후에는 현재 cache 상태에 맞춰 full/parent/tag 중 필요한 범위만 다시 동기화합니다.
  Future<void> _reloadCommentsForPost(int postId) async {
    final controller = _taggingController;
    if (controller == null) {
      return;
    }

    if (context.read<CommentController>().peekCommentsCache(postId: postId) !=
        null) {
      await controller.loadCommentsForScope(
        _postScopeId(postId),
        forceReload: true,
      );
      return;
    }

    if (context.read<CommentController>().peekParentCommentsCache(
          postId: postId,
        ) !=
        null) {
      await controller.loadParentCommentsForScope(
        _postScopeId(postId),
        forceReload: true,
      );
      return;
    }

    await controller.loadParentCommentsForScope(
      _postScopeId(postId),
      forceReload: true,
    );
  }

  /// 댓글시트는 mount 직후 full thread를 hydrate하고 재오픈 시에는 full cache를 재사용합니다.
  Future<List<Comment>> _loadFullCommentsForPost(int postId) async {
    final controller = _taggingController;
    if (controller == null) {
      return const <Comment>[];
    }
    return SoiTagCommentMapper.toComments(
      await controller.loadCommentsForScope(_postScopeId(postId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 90.w,
        title: Column(
          children: [
            Text(
              tr('common.app_name', context: context),
              style: TextStyle(
                color: const Color(0xfff9f9f9),
                fontSize: 20.sp,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
        backgroundColor: Colors.black,
        toolbarHeight: 70.h,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 화면이 실제로 소비하는 피드 상태만 선택해서 불필요한 전체 rebuild를 줄입니다.
    final feedViewState = context
        .select<
          FeedDataManager,
          ({
            bool isLoading,
            bool hasPosts,
            List<FeedPostItem> visiblePosts,
            bool hasMoreData,
            bool isLoadingMore,
          })
        >(
          (manager) => (
            isLoading: manager.isLoading,
            hasPosts: manager.allPosts.isNotEmpty,
            visiblePosts: manager.visiblePosts,
            hasMoreData: manager.hasMoreData,
            isLoadingMore: manager.isLoadingMore,
          ),
        );
    _feedDataManager ??= context.read<FeedDataManager>();
    if (_taggingController == null || _taggingSaveDelegate == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (feedViewState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!feedViewState.hasPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.white54,
              size: 80,
            ),
            SizedBox(height: 16.h),
            Text(
              tr('feed.empty_title', context: context),
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              tr('feed.empty_description', context: context),
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      // 당겨서 새로고침은 서버에서 다시 가져오도록 강제 리프레시합니다.
      onRefresh: _handleFeedRefresh,
      color: Colors.white,
      backgroundColor: Colors.black,
      child: FeedPageBuilder(
        pageController: _feedPageController,
        posts: feedViewState.visiblePosts,
        hasMoreData: feedViewState.hasMoreData,
        isLoadingMore: feedViewState.isLoadingMore,
        selectedEmojisByScopeId: _taggingController!.selectedEmojisByScopeId,
        pendingCommentDrafts: _taggingController!.pendingDrafts,
        pendingVoiceComments: _taggingController!.pendingMarkers,
        taggingController: _taggingController!,
        saveDelegate: _taggingSaveDelegate!,
        onToggleAudio: _toggleAudio,
        onTextCommentCompleted: _onTextCommentCompleted,
        onAudioCommentCompleted: _onAudioCommentCompleted,
        onMediaCommentCompleted: _onMediaCommentCompleted,
        onProfileImageDragged: _onProfileImageDragged,
        onCommentSaveProgress: _onCommentSaveProgress,
        onCommentSaveSuccess: _onCommentSaveSuccess,
        onCommentSaveFailure: _onCommentSaveFailure,
        onDeletePost: _deletePost,
        onPageChanged: (index) => _handlePageChanged(index),
        onStopAllAudio: _stopAllAudio,
        currentUserNickname: _userController?.currentUser?.userId,
        onReloadComments: _reloadCommentsForPost,
        onLoadFullComments: _loadFullCommentsForPost,
        onEmojiSelected: (postId, emoji) =>
            _taggingController!.setSelectedEmoji(_postScopeId(postId), emoji),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    SnackBarUtils.showSnackBar(context, message);
  }
}
